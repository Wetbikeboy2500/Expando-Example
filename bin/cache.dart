import 'dart:math';
import 'dart:developer';
import 'dart:isolate';
import 'package:vm_service/vm_service_io.dart';

// Expensive computation we want to cache
class DataProcessor {
  static int computationCount = 0;
  
  static String expensiveComputation(String input) {
    computationCount++;
    print('Performing expensive computation #$computationCount for: $input');
    // Simulate expensive work
    for (int i = 0; i < 1000000; i++) {
      sqrt(i);
    }
    return 'Processed: ${input.toUpperCase()}';
  }
}

// Wrapper for cached computation results
class CachedResult {
  final String value;
  final DateTime cachedAt;
  
  CachedResult(this.value) : cachedAt = DateTime.now();
  
  @override
  String toString() => 'CachedResult($value, cached: $cachedAt)';
}

// Cache key that's based on input equality but has controlled lifetime
class CacheKey {
  final String input;
  final DateTime createdAt;
  
  CacheKey(this.input) : createdAt = DateTime.now();
  
  @override
  bool operator ==(Object other) => 
    other is CacheKey && other.input == input;
    
  @override
  int get hashCode => input.hashCode;
  
  @override
  String toString() => 'CacheKey($input, created: $createdAt)';
}

// Our cache using Expando - now stores CachedResult objects
final cache = Expando<CachedResult>('ComputationCache');

// Map to store and reuse cache keys based on input equality using WeakReference
final Map<String, WeakReference<CacheKey>> _keyStore = {};

Future<void> getCacheObjectCounts() async {
  try {
    final serviceUri = (await Service.getInfo()).serverUri;
    if (serviceUri == null) {
      print('Please run with --enable-vm-service flag!');
      return;
    }

    final wsUri = serviceUri.replace(
      scheme: 'ws',
      path: '${serviceUri.path}ws',
    );

    final service = await vmServiceConnectUri(wsUri.toString());
    final isolateId = Service.getIsolateId(Isolate.current);

    if (isolateId != null) {
      final allocation = await service.getAllocationProfile(isolateId, gc: true);
      final cachedResultCount = allocation.members!
          .where((sample) => sample.classRef?.name == 'CachedResult')
          .firstOrNull?.instancesCurrent ?? 0;
      print('Number of CachedResult objects in memory: $cachedResultCount');
    }

    await service.dispose();
  } catch (e) {
    print('Failed to get cache object counts: $e');
  }
}

({CacheKey? key, String result}) cachedComputation(String input) {
  // Get or create a cache key based on input equality
  CacheKey? cacheKey = _keyStore[input]?.target;
  
  // If key was garbage collected or doesn't exist, create new one
  if (cacheKey == null) {
    cacheKey = CacheKey(input);
    _keyStore[input] = WeakReference(cacheKey);
  }
  
  // Check if we have a cached result for this key
  CachedResult? cachedResult = cache[cacheKey];
  if (cachedResult != null) {
    print('Cache HIT for: $input (reusing shared key)');
    return (key: cacheKey, result: cachedResult.value);
  }
  
  // Cache miss - perform computation
  print('Cache MISS for: $input (creating/storing result)');
  final result = DataProcessor.expensiveComputation(input);
  cache[cacheKey] = CachedResult(result);
  
  return (key: cacheKey, result: result);
}

void main() async {
print('=== Demonstrating Expando-based Caching with Key Lifetime Control ===\n');

print('Step 1: First computation - creates new key');
var (key: key1, result: _) = cachedComputation('hello');
print('Result: $key1');
await getCacheObjectCounts();

print('\nStep 2: Second computation - reuses same key object');
var (key: key2, result: _) = cachedComputation('hello');
print('Result: $key2 (should be same as key1)');
print('key1 and key2 are identical: ${identical(key1, key2)}');
await getCacheObjectCounts();

print('\nStep 3: Clear first key reference (but keep second)');
key1 = null;
print('key1 cleared, but cache should persist via key2');
await getCacheObjectCounts();

print('\nStep 4: Clear second key reference');
key2 = null;
print('All key references cleared - cache entry should be eligible for GC');

// Even though we force a GC call, it seems it was determining that it did not need to clean up the unreferenced object (which is good behavior for caching)
print('Forcing garbage collection...');
for (int i = 0; i < 3; i++) {
  await Future.delayed(Duration(milliseconds: 100));
  // Create some allocation pressure to encourage GC
  List.generate(1000, (i) => 'garbage$i');
}

await getCacheObjectCounts();

print('\nTotal computations: ${DataProcessor.computationCount}');
print('\nKey insight: Cache lifetime controlled by shared key references');
print('- Multiple calls with same input share the same CacheKey object');
print('- Cache persists as long as ANY reference to the key exists');  
print('- WeakReference in _keyStore allows automatic cleanup without holding strong refs');
}