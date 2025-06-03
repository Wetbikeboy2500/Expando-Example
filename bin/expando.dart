import 'dart:developer';
import 'dart:isolate';
import 'package:vm_service/vm_service_io.dart';

Future<void> main(List<String> arguments) async {
  final Expando<Birthday> weakData = Expando<Birthday>('WeakData');

  print('\nStep 1: Demonstrating reference-based lookup');
  // Create our test objects
  Person? dave = Person('Dave', 28);
  Person? eve = Person('Eve', 32);
  Person? daveCopy = Person('Dave', 28);

  // Show equality behavior
  print('dave == daveCopy: ${dave == daveCopy}'); // true
  print('dave.hashCode == daveCopy.hashCode: ${dave.hashCode == daveCopy.hashCode}'); // true

  // Demonstrate reference-based lookup
  weakData[dave] = Birthday(DateTime(1995, 5, 15)); // Dave's birthday
  weakData[eve] = Birthday(DateTime(1991, 8, 22)); // Eve's birthday
  print('Birthday for dave: ${weakData[dave]}');
  print('Birthday for daveCopy: ${weakData[daveCopy]}'); // null, despite being equal
  print('Birthday for eve: ${weakData[eve]}');

  print('\nStep 2: Initial Person object count');
  await getNumberOfPersonObjectsAfterGC();

  print('\nStep 3: Clearing Dave\'s reference');
  dave = null;

  print('\nStep 4: Checking Person and Birthday count after clearing Dave');
  await getNumberOfPersonObjectsAfterGC();

  print('\nStep 5: Clearing remaining references');
  eve = null;

  print('\nStep 6: Final Person and Birthday count after clearing all references');
  await getNumberOfPersonObjectsAfterGC();
}

Future<void> getNumberOfPersonObjectsAfterGC() async {
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
      final personCount =
          allocation.members!.where((sample) => sample.classRef?.name == 'Person').first.instancesCurrent ?? 0;
      final birthdayCount =
          allocation.members!.where((sample) => sample.classRef?.name == 'Birthday').first.instancesCurrent ?? 0;
      print('Number of Person objects: $personCount');
      print('Number of Birthday objects: $birthdayCount');
    }

    await service.dispose();
  } catch (e) {
    print('Failed to get number of Person and PersonBirthday objects: $e');
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
