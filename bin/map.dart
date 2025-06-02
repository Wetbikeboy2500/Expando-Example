import 'dart:developer';
import 'dart:isolate';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> arguments) async {
  // Use a Map instead of Expando
  final Map<Person, Birthday> mapData = {};
  
  print('\nStep 1: Demonstrating equality-based lookup with Map');
  // Create our test objects
  Person? dave = Person('Dave', 28);
  Person? eve = Person('Eve', 32);
  Person? daveCopy = Person('Dave', 28);
  
  // Show equality behavior
  print('dave == daveCopy: ${dave == daveCopy}'); // true
  print('dave.hashCode == daveCopy.hashCode: ${dave.hashCode == daveCopy.hashCode}'); // true
  
  // Demonstrate Map's equality-based lookup
  mapData[dave] = Birthday(DateTime(1995, 5, 15)); // Dave's birthday
  mapData[eve] = Birthday(DateTime(1991, 8, 22)); // Eve's birthday
  print('Birthday for dave: ${mapData[dave]}');
  print('Birthday for daveCopy: ${mapData[daveCopy]}'); // Works, uses equality!
  print('Birthday for eve: ${mapData[eve]}');
  print('Map size: ${mapData.length}'); // Will be 2, not 3
  
  print('\nStep 2: Initial Person object count');
  await getNumberOfObjectsAfterGC();
  
  print('\nStep 3: Clearing Dave\'s reference');
  dave = null;
  
  print('\nStep 4: Checking Person and Birthday count after clearing Dave');
  await getNumberOfObjectsAfterGC();
  print('Map size: ${mapData.length}'); // Still 2
  print('Map keys contain daveCopy: ${mapData.containsKey(daveCopy)}'); // True
  
  print('\nStep 5: Clearing remaining references');
  eve = null;
  
  print('\nStep 6: Final Person and Birthday count after clearing all references');
  await getNumberOfObjectsAfterGC();
  print('Map size: ${mapData.length}'); // Still 2
  print('Map keys contain daveCopy: ${mapData.containsKey(daveCopy)}'); // True
}

Future<void> getNumberOfObjectsAfterGC() async {
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
      final personCount = allocation.members!.where((sample) => sample.classRef?.name == 'Person').first.instancesCurrent ?? 0;
      final birthdayCount = allocation.members!.where((sample) => sample.classRef?.name == 'Birthday').first.instancesCurrent ?? 0;
      print('Number of Person objects: $personCount');
      print('Number of Birthday objects: $birthdayCount');
    }

    await service.dispose();
  } catch (e) {
    print('Failed to get number of objects: $e');
  }
}

class Person {
  final String name;
  final int age;

  Person(this.name, this.age);

  @override
  String toString() => '$name ($age)';

  @override
  int get hashCode => name.hashCode ^ age.hashCode;

  @override
  bool operator ==(Object other) => other is Person && other.name == name && other.age == age;
}

class Birthday {
  final DateTime birthday;

  Birthday(this.birthday);

  @override
  String toString() => 'Birthday: ${birthday.toLocal()}';
}
