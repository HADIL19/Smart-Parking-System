

abstract class Vehicle {
  final String plateNumber;
  final VehicleType type;
  final DateTime entryTime;

  Vehicle(this.plateNumber, this.type) : entryTime = DateTime.now();
}




class Car extends Vehicle {
  Car(String plateNumber) : super(plateNumber, VehicleType.car);

}

class Motorcycle extends Vehicle {
  Motorcycle(String plateNumber) : super(plateNumber, VehicleType.motorcycle);
}
class Truck extends Vehicle {
  Truck(String plateNumber) : super(plateNumber, VehicleType.truck);
}
