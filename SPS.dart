import 'dart:async';
import 'dart:io';
import 'dart:math';

// Enums
enum VehicleType { car, motorcycle, truck }
enum ParkingStatus { available, occupied }

// Mixins
mixin LoggerMixin {
  final List<String> _logs = [];

  void log(dynamic message) {
    final timestamp = DateTime.now().toString();
    _logs.add('[$timestamp] $message');
  }

  List<String> get logs => _logs;
}

// Classes
abstract class Vehicle {
  final String plateNumber;
  final VehicleType type;
  final DateTime entryTime;

  Vehicle(this.plateNumber, this.type) : entryTime = DateTime.now();

  double calculateFee(DateTime exitTime) {
    final duration = exitTime.difference(entryTime).inMinutes / 60.0;
    return _getBaseRate() * max(1, duration);
  }

  double _getBaseRate();

  @override
  String toString() {
    String vehicleTypeStr;
    switch (type) {
      case VehicleType.car:
        vehicleTypeStr = 'CAR';
        break;
      case VehicleType.motorcycle:
        vehicleTypeStr = 'MOTORCYCLE';
        break;
      case VehicleType.truck:
        vehicleTypeStr = 'TRUCK';
        break;
    }
    return '$vehicleTypeStr - $plateNumber';
  }
}

class Car extends Vehicle {
  Car(String plateNumber) : super(plateNumber, VehicleType.car);

  @override
  double _getBaseRate() => 10.0; // $10 per hour for cars
}

class Motorcycle extends Vehicle {
  Motorcycle(String plateNumber) : super(plateNumber, VehicleType.motorcycle);

  @override
  double _getBaseRate() => 5.0; // $5 per hour for motorcycles
}

class Truck extends Vehicle {
  Truck(String plateNumber) : super(plateNumber, VehicleType.truck);

  @override
  double _getBaseRate() => 15.0; // $15 per hour for trucks
}

class ParkingTicket {
  final String id;
  final Vehicle vehicle;
  final int slotNumber;
  final DateTime entryTime;
  DateTime? exitTime;
  double? fee;

  ParkingTicket({
    required this.id,
    required this.vehicle,
    required this.slotNumber,
  }) : entryTime = DateTime.now();

  void completeTicket(DateTime exitTime, double fee) {
    this.exitTime = exitTime;
    this.fee = fee;
  }

  String generateReceipt() {
    if (exitTime == null || fee == null) {
      throw Exception('Ticket not completed yet');
    }

    final duration = exitTime!.difference(entryTime).inMinutes / 60.0;

    return '''
    ======== PARKING RECEIPT ========
    Ticket ID: $id
    Vehicle: ${vehicle.toString()}
    Entry Time: $entryTime
    Exit Time: $exitTime
    Duration: ${duration.toStringAsFixed(1)} hours
    Total Fee: \$${fee!.toStringAsFixed(2)}
    ================================
''';
  }
}

class ParkingManager<T extends Vehicle> {
  final Map<int, T?> _parkingSlots = {};
  final Map<String, ParkingTicket> _activeTickets = {};
  final List<ParkingTicket> _completedTickets = [];
  final Set<String> _whitelistedPlates = {};
  final StreamController<int> _availabilityController = StreamController<int>.broadcast();

  ParkingManager(int totalSlots) {
    for (int i = 0; i < totalSlots; i++) {
      _parkingSlots[i] = null;
    }
  }

  Stream<int> get availabilityStream => _availabilityController.stream;

  void addToWhitelist(String plateNumber) {
    _whitelistedPlates.add(plateNumber);
  }

  bool isWhitelisted(String plateNumber) {
    return _whitelistedPlates.isEmpty || _whitelistedPlates.contains(plateNumber);
  }

  Future<ParkingTicket?> parkVehicle(T vehicle) async {
    if (!isWhitelisted(vehicle.plateNumber)) {
      return null; // Vehicle not allowed
    }

    int? availableSlot;
    for (final entry in _parkingSlots.entries) {
      if (entry.value == null) {
        availableSlot = entry.key;
        break;
      }
    }

    if (availableSlot == null) {
      return null; // No parking slot available
    }

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));

    _parkingSlots[availableSlot] = vehicle;
    
    final ticketId = 'T${DateTime.now().millisecondsSinceEpoch}';
    final ticket = ParkingTicket(
      id: ticketId,
      vehicle: vehicle,
      slotNumber: availableSlot + 1, // Display slot numbers from 1, not 0
    );
    
    _activeTickets[vehicle.plateNumber] = ticket;
    
    // Notify about availability change
    _notifyAvailabilityChange();
    
    return ticket;
  }

  Future<ParkingTicket?> retrieveVehicle(String plateNumber) async {
    if (!_activeTickets.containsKey(plateNumber)) {
      return null; // Vehicle not found
    }

    // Simulate processing delay
    await Future.delayed(const Duration(milliseconds: 500));

    final ticket = _activeTickets[plateNumber]!;
    final vehicle = ticket.vehicle;
    
    // Find the slot
    int? slot;
    for (final entry in _parkingSlots.entries) {
      if (entry.value != null && entry.value!.plateNumber == plateNumber) {
        slot = entry.key;
        break;
      }
    }

    if (slot == null) {
      return null; // Something went wrong
    }

    // Calculate fee
    final exitTime = DateTime.now();
    final fee = vehicle.calculateFee(exitTime);
    
    // Complete the ticket
    ticket.completeTicket(exitTime, fee);
    
    // Remove the vehicle from slot
    _parkingSlots[slot] = null;
    
    // Remove from active tickets and add to completed
    _activeTickets.remove(plateNumber);
    _completedTickets.add(ticket);
    
    // Notify about availability change
    _notifyAvailabilityChange();
    
    return ticket;
  }

  int getAvailableSlots() {
    return _parkingSlots.values.where((v) => v == null).length;
  }

  int getTotalSlots() {
    return _parkingSlots.length;
  }

  Map<int, ParkingStatus> getParkingStatus() {
    final Map<int, ParkingStatus> status = {};
    
    for (final entry in _parkingSlots.entries) {
      status[entry.key + 1] = entry.value == null 
          ? ParkingStatus.available
          : ParkingStatus.occupied;
    }
    
    return status;
  }

  List<ParkingTicket> getCompletedTickets() {
    return _completedTickets;
  }

  void _notifyAvailabilityChange() {
    _availabilityController.add(getAvailableSlots());
  }

  void dispose() {
    _availabilityController.close();
  }
}

class ParkingLot with LoggerMixin {
  final ParkingManager<Vehicle> _manager;
  final int _totalSlots;
  
  ParkingLot(this._totalSlots) : _manager = ParkingManager<Vehicle>(_totalSlots) {
    log('Smart Parking System started' as dynamic);
    
    // Subscribe to availability updates
    _manager.availabilityStream.listen((available) {
      print('Availability updated: $available/$_totalSlots slots available');
    });
  }

  Future<ParkingTicket?> parkVehicle(Vehicle vehicle) async {
    log('Vehicle entry process initiated' as dynamic);
    
    final vehicleTypeStr = vehicle.type == VehicleType.car 
        ? 'Car' 
        : (vehicle.type == VehicleType.motorcycle ? 'Motorcycle' : 'Truck');
    
    log('$vehicleTypeStr selected: ${vehicle.plateNumber}' as dynamic);
    
    final ticket = await _manager.parkVehicle(vehicle);
    
    if (ticket != null) {
      print('Vehicle ${vehicle.plateNumber} parked at slot ${ticket.slotNumber - 1}');
      log('Ticket issued: ${ticket.id} for vehicle ${vehicle.plateNumber}' as dynamic);
    } else {
      print('Failed to park vehicle ${vehicle.plateNumber}');
      log('Parking failed for vehicle ${vehicle.plateNumber}' as dynamic);
    }
    
    return ticket;
  }

  Future<ParkingTicket?> retrieveVehicle(String plateNumber) async {
    log('Vehicle exit process initiated' as dynamic);
    
    final ticket = await _manager.retrieveVehicle(plateNumber);
    
    if (ticket != null && ticket.fee != null) {
      print('Vehicle $plateNumber exited. Fee: \$${ticket.fee!.toStringAsFixed(2)}');
      log('Receipt generated for ticket ${ticket.id}, vehicle $plateNumber' as dynamic);
    } else {
      print('Failed to retrieve vehicle $plateNumber');
      log('Failed to retrieve vehicle $plateNumber' as dynamic);
    }
    
    return ticket;
  }

  void checkAvailability() {
    final available = _manager.getAvailableSlots();
    final total = _manager.getTotalSlots();
    
    print('Parking status checked: $available/$total slots available');
    log('Availability check requested' as dynamic);
    
    print('\n=== PARKING LOT STATUS ===');
    final status = _manager.getParkingStatus();
    for (final entry in status.entries) {
      final statusStr = entry.value == ParkingStatus.available ? 'AVAILABLE' : 'OCCUPIED';
      print('Slot ${entry.key}: $statusStr');
    }
    print('========================\n');
    print('Total Available Slots: $available/$total\n');
  }
  
  List<String> getTransactionLogs() {
    return logs;
  }
  
  List<ParkingTicket> getCompletedTickets() {
    return _manager.getCompletedTickets();
  }
  
  void dispose() {
    _manager.dispose();
  }
}

void main() async {
  const int TOTAL_SLOTS = 10;
  final parkingLot = ParkingLot(TOTAL_SLOTS);
  
  print('Parking lot initialized with $TOTAL_SLOTS slots');
  
  print('\n🚗 Welcome to Smart Parking System! 🚗\n');
  
  bool running = true;
  
  while (running) {
    print('=== SMART PARKING SYSTEM MENU ===');
    print('1. Park a vehicle');
    print('2. Check available slots');
    print('3. Retrieve a parked vehicle');
    print('4. View transaction log');
    print('5. Exit');
    stdout.write('Select an option: ');
    
    final input = stdin.readLineSync();
    
    switch (input) {
      case '1':
        print('\n=== VEHICLE ENTRY ===');
        stdout.write('Enter vehicle plate number: ');
        final plateNumber = stdin.readLineSync() ?? '';
        
        if (plateNumber.isEmpty) {
          print('Invalid plate number');
          continue;
        }
        
        print('Select vehicle type:');
        print('1. Car');
        print('2. Motorcycle');
        print('3. Truck');
        final vehicleTypeInput = stdin.readLineSync();
        
        Vehicle? vehicle;
        switch (vehicleTypeInput) {
          case '1':
            vehicle = Car(plateNumber);
            break;
          case '2':
            vehicle = Motorcycle(plateNumber);
            break;
          case '3':
            vehicle = Truck(plateNumber);
            break;
          default:
            print('Invalid vehicle type');
            continue;
        }
        
        print('\nProcessing... Please wait.');
        final ticket = await parkingLot.parkVehicle(vehicle);
        
        if (ticket != null) {
          print('\n✅ Vehicle parked successfully!');
          print('Ticket ID: ${ticket.id}');
          print('Slot Number: ${ticket.slotNumber}');
          print('Entry Time: ${ticket.entryTime}\n');
        } else {
          print('\n❌ Failed to park vehicle. No slots available or access denied.\n');
        }
        break;
        
      case '2':
        parkingLot.checkAvailability();
        break;
        
      case '3':
        print('\n=== VEHICLE EXIT ===');
        stdout.write('Enter vehicle plate number: ');
        final plateNumber = stdin.readLineSync() ?? '';
        
        if (plateNumber.isEmpty) {
          print('Invalid plate number');
          continue;
        }
        
        print('\nProcessing... Please wait.');
        final ticket = await parkingLot.retrieveVehicle(plateNumber);
        
        if (ticket != null) {
          print('\n✅ Vehicle retrieved successfully!');
          print(ticket.generateReceipt());
        } else {
          print('\n❌ Vehicle not found in the parking lot.\n');
        }
        break;
        
      case '4':
        print('\n=== TRANSACTION LOG ===');
        for (final log in parkingLot.getTransactionLogs()) {
          print(log);
        }
        
        final completedTickets = parkingLot.getCompletedTickets();
        print('\n=== COMPLETED TICKETS ===');
        if (completedTickets.isEmpty) {
          print('No completed tickets yet.');
        } else {
          for (final ticket in completedTickets) {
            print('Ticket ID: ${ticket.id}');
            print('Vehicle: ${ticket.vehicle.toString()}');
            print('Entry: ${ticket.entryTime}');
            print('Exit: ${ticket.exitTime}');
            print('Fee: \$${ticket.fee!.toStringAsFixed(2)}');
            print('-------------------');
          }
        }
        print('');
        break;
        
      case '5':
        running = false;
        print('\nThank you for using Smart Parking System! Goodbye! 👋');
        print('Parking system shutting down');
        break;
        
      default:
        print('\nInvalid option. Please try again.\n');
    }
  }
  
  parkingLot.dispose();
}