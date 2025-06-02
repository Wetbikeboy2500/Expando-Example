# Expando Weak Reference Example

This example demonstrates how Dart's `Expando` class works with weak references and garbage collection, compared to a standard `Map`.

## Running the Examples

Run the Expando example:
```bash
dart run --enable-vm-service bin/expando.dart
```

Run the Map example:
```bash
dart run --enable-vm-service bin/map.dart
```

## Key Differences

1. **Lookup Mechanism**
   - Expando uses object identity/reference for lookup
   - Map uses object equality (==) for lookup

2. **Garbage Collection**
   - Expando uses weak references - when an object is garbage collected, its entry is removed
   - Map maintains strong references - prevents key objects from being garbage collected

3. **Memory Management**
   - Expando allows objects to be garbage collected when no other references exist
   - Map keeps objects alive as long as they're used as keys

## Expando Example

### Step 1: Demonstrating reference-based lookup

```dart
// Create an Expando to store Birthday objects
final Expando<Birthday> weakData = Expando<Birthday>('WeakData');

// Create test objects
Person? dave = Person('Dave', 28);
Person? eve = Person('Eve', 32);
Person? daveCopy = Person('Dave', 28);

// Show equality behavior
print('dave == daveCopy: ${dave == daveCopy}');
print('dave.hashCode == daveCopy.hashCode: ${dave.hashCode == daveCopy.hashCode}');

// Demonstrate reference-based lookup
weakData[dave] = Birthday(DateTime(1995, 5, 15));
weakData[eve] = Birthday(DateTime(1991, 8, 22));
print('Birthday for dave: ${weakData[dave]}');
print('Birthday for daveCopy: ${weakData[daveCopy]}'); // null, despite being equal
print('Birthday for eve: ${weakData[eve]}');
```

**Output:**
```
Step 1: Demonstrating reference-based lookup
dave == daveCopy: true
dave.hashCode == daveCopy.hashCode: true
Birthday for dave: Birthday: 1995-05-15 00:00:00.000
Birthday for daveCopy: null
Birthday for eve: Birthday: 1991-08-22 00:00:00.000
```

### Step 2: Initial Person object count

```dart
// Check initial object counts after GC
await getNumberOfPersonObjectsAfterGC();

// getNumberOfPersonObjectsAfterGC() implementation
Future<void> getNumberOfPersonObjectsAfterGC() async {
  // Connect to VM service
  // ...existing code...
  
  // Get and display the counts
  final personCount = allocation.members!.where((sample) => 
      sample.classRef?.name == 'Person').first.instancesCurrent ?? 0;
  final birthdayCount = allocation.members!.where((sample) => 
      sample.classRef?.name == 'Birthday').first.instancesCurrent ?? 0;
  print('Number of Person objects: $personCount');
  print('Number of Birthday objects: $birthdayCount');
}
```

**Output:**
```
Step 2: Initial Person object count
Number of Person objects: 3
Number of Birthday objects: 2
```

### Step 3-4: Clearing Dave's reference and checking counts

```dart
// Clear dave reference to make it eligible for GC
print('\nStep 3: Clearing Dave\'s reference');
dave = null;

// Check object counts after clearing dave
print('\nStep 4: Checking Person and Birthday count after clearing Dave');
await getNumberOfPersonObjectsAfterGC();
```

**Output:**
```
Step 3: Clearing Dave's reference

Step 4: Checking Person and Birthday count after clearing Dave
Number of Person objects: 2
Number of Birthday objects: 1
```

### Step 5-6: Clearing remaining references and final count

```dart
// Clear eve reference to make it eligible for GC
print('\nStep 5: Clearing remaining references');
eve = null;

// Check final object counts after clearing all references
print('\nStep 6: Final Person and Birthday count after clearing all references');
await getNumberOfPersonObjectsAfterGC();
```

**Output:**
```
Step 5: Clearing remaining references

Step 6: Final Person and Birthday count after clearing all references
Number of Person objects: 1
Number of Birthday objects: 0
```


**Note**: The `--enable-vm-service` flag is required to interact with the VM's garbage collector and track object allocations.
