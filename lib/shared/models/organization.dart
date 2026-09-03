import '../enums/app_enums.dart';

/// Geographic hierarchy: Territory > Area > Cluster (§68).
class Territory {
  const Territory({
    required this.id,
    required this.name,
    required this.headquarters,
    this.areaIds = const [],
  });

  final String id;
  final String name;
  final String headquarters;
  final List<String> areaIds;
}

class Area {
  const Area({
    required this.id,
    required this.name,
    required this.territoryId,
    this.clusterIds = const [],
  });

  final String id;
  final String name;
  final String territoryId;
  final List<String> clusterIds;
}

class Cluster {
  const Cluster({required this.id, required this.name, required this.areaId});

  final String id;
  final String name;
  final String areaId;
}

/// A person in the organization.
///
/// [managerId] forms the reporting tree that [DataScope] walks; a null manager
/// means the top of the hierarchy.
class Employee {
  const Employee({
    required this.id,
    required this.employeeCode,
    required this.name,
    required this.role,
    required this.designation,
    required this.mobile,
    required this.email,
    required this.territoryId,
    required this.territoryName,
    required this.headquarters,
    this.managerId,
    this.managerName,
    this.areaId,
    this.areaName,
    this.clusterId,
    this.clusterName,
    this.department = 'Sales & Marketing',
    this.photoUrl,
    this.joiningDate,
    this.bloodGroup,
    this.isActive = true,
    this.lastKnownLatitude,
    this.lastKnownLongitude,
    this.lastSeenAt,
  });

  final String id;
  final String employeeCode;
  final String name;
  final UserRole role;
  final String designation;
  final String mobile;
  final String email;
  final String territoryId;
  final String territoryName;
  final String headquarters;
  final String? managerId;
  final String? managerName;
  final String? areaId;
  final String? areaName;
  final String? clusterId;
  final String? clusterName;
  final String department;
  final String? photoUrl;
  final DateTime? joiningDate;
  final String? bloodGroup;
  final bool isActive;

  /// Last reported position, used by the team map (§42). Null until the
  /// employee records an activity with location.
  final double? lastKnownLatitude;
  final double? lastKnownLongitude;
  final DateTime? lastSeenAt;

  DataScope get scope => DataScope.forRole(role);

  /// Display line used under the name throughout the app.
  String get subtitle => '$designation · $headquarters';
}

/// Immutable snapshot of who is signed in and what they may see.
class Session {
  const Session({
    required this.employee,
    required this.loginAt,
    this.token = 'mock-session-token',
  });

  final Employee employee;
  final DateTime loginAt;
  final String token;

  UserRole get role => employee.role;
  DataScope get scope => employee.scope;

  bool get isManager => role.isManager;
  bool get isAdmin => role.isAdmin;
  bool get isFieldUser => role.isFieldUser;
}
