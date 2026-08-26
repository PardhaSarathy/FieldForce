import 'dart:math' as math;
import 'dart:math' show Random;

import '../../core/location/geo_math.dart';
import '../../shared/enums/app_enums.dart';
import '../../shared/models/activity.dart';
import '../../shared/models/business.dart';
import '../../shared/models/client.dart';
import '../../shared/models/engagement.dart';
import '../../shared/models/field_ops.dart';
import '../../shared/models/organization.dart';

/// In-memory seed data standing in for the backend.
///
/// Two rules govern this file:
///
/// 1. **Deterministic.** A fixed RNG seed means every launch, screenshot and
///    test sees the same world. Random demo data makes UI review impossible.
/// 2. **Internally consistent.** Reports are computed from these activities and
///    orders, not hardcoded alongside them — so if a screen shows "3 of 10
///    visits", ten activity records actually exist. This is what §66.9 demands
///    of the real system, and building the mock the same way means the
///    aggregation logic is exercised now rather than written later.
class MockDataset {
  MockDataset._();

  static final MockDataset instance = MockDataset._();

  final _rng = Random(20260826);

  /// "Today" is pinned to the real current date so the app always opens on a
  /// live-looking day, but times of day are generated deterministically.
  late final DateTime today = _dateOnly(DateTime.now());

  // ======================================================== organization ==

  late final List<Territory> territories = const [
    Territory(id: 'ter-1', name: 'Mumbai South', headquarters: 'Mumbai'),
    Territory(id: 'ter-2', name: 'Mumbai West', headquarters: 'Mumbai'),
    Territory(id: 'ter-3', name: 'Pune', headquarters: 'Pune'),
  ];

  late final List<Area> areas = const [
    Area(id: 'ar-1', name: 'Andheri East', territoryId: 'ter-1'),
    Area(id: 'ar-2', name: 'Bandra', territoryId: 'ter-1'),
    Area(id: 'ar-3', name: 'Dadar', territoryId: 'ter-1'),
    Area(id: 'ar-4', name: 'Goregaon', territoryId: 'ter-2'),
    Area(id: 'ar-5', name: 'Borivali', territoryId: 'ter-2'),
    Area(id: 'ar-6', name: 'Kothrud', territoryId: 'ter-3'),
  ];

  late final List<Cluster> clusters = const [
    Cluster(id: 'cl-1', name: 'Chakala', areaId: 'ar-1'),
    Cluster(id: 'cl-2', name: 'MIDC', areaId: 'ar-1'),
    Cluster(id: 'cl-3', name: 'Linking Road', areaId: 'ar-2'),
    Cluster(id: 'cl-4', name: 'Shivaji Park', areaId: 'ar-3'),
  ];

  /// The signed-in field user for the default demo session.
  late final Employee currentUser = employees.first;

  late final List<Employee> employees = [
    Employee(
      id: 'emp-1',
      employeeCode: 'MR1001',
      name: 'Rahul Kumar',
      role: UserRole.mr,
      designation: 'Medical Representative',
      mobile: '9876543210',
      email: 'rahul.kumar@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'Mumbai South',
      headquarters: 'Mumbai South',
      managerId: 'emp-10',
      managerName: 'Ramesh Iyer',
      areaId: 'ar-1',
      areaName: 'Andheri East',
      clusterId: 'cl-1',
      clusterName: 'Chakala',
      joiningDate: DateTime(2022, 4, 11),
      bloodGroup: 'O+',
      lastKnownLatitude: 19.1136,
      lastKnownLongitude: 72.8697,
      lastSeenAt: today.add(const Duration(hours: 10, minutes: 32)),
    ),
    Employee(
      id: 'emp-2',
      employeeCode: 'MR1002',
      name: 'Sneha Patil',
      role: UserRole.mr,
      designation: 'Medical Representative',
      mobile: '9822011223',
      email: 'sneha.patil@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'Mumbai South',
      headquarters: 'Mumbai South',
      managerId: 'emp-10',
      managerName: 'Ramesh Iyer',
      areaId: 'ar-2',
      areaName: 'Bandra',
      joiningDate: DateTime(2023, 1, 9),
      bloodGroup: 'B+',
      lastKnownLatitude: 19.0596,
      lastKnownLongitude: 72.8295,
      lastSeenAt: today.add(const Duration(hours: 11, minutes: 5)),
    ),
    Employee(
      id: 'emp-3',
      employeeCode: 'MR1003',
      name: 'Imran Shaikh',
      role: UserRole.mr,
      designation: 'Medical Representative',
      mobile: '9700112233',
      email: 'imran.shaikh@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'Mumbai South',
      headquarters: 'Mumbai South',
      managerId: 'emp-10',
      managerName: 'Ramesh Iyer',
      areaId: 'ar-3',
      areaName: 'Dadar',
      joiningDate: DateTime(2021, 8, 2),
      bloodGroup: 'A+',
      lastKnownLatitude: 19.0176,
      lastKnownLongitude: 72.8438,
      lastSeenAt: today.add(const Duration(hours: 9, minutes: 48)),
    ),
    Employee(
      id: 'emp-4',
      employeeCode: 'MR1004',
      name: 'Priya Nair',
      role: UserRole.mr,
      designation: 'Senior Medical Representative',
      mobile: '9611223344',
      email: 'priya.nair@pharmaconnect.in',
      territoryId: 'ter-2',
      territoryName: 'Mumbai West',
      headquarters: 'Mumbai West',
      managerId: 'emp-10',
      managerName: 'Ramesh Iyer',
      areaId: 'ar-4',
      areaName: 'Goregaon',
      joiningDate: DateTime(2020, 6, 15),
      bloodGroup: 'AB+',
      lastKnownLatitude: 19.1663,
      lastKnownLongitude: 72.8526,
      lastSeenAt: today.add(const Duration(hours: 10, minutes: 12)),
    ),
    Employee(
      id: 'emp-5',
      employeeCode: 'MR1005',
      name: 'Vikram Desai',
      role: UserRole.mr,
      designation: 'Medical Representative',
      mobile: '9533445566',
      email: 'vikram.desai@pharmaconnect.in',
      territoryId: 'ter-2',
      territoryName: 'Mumbai West',
      headquarters: 'Mumbai West',
      managerId: 'emp-10',
      managerName: 'Ramesh Iyer',
      areaId: 'ar-5',
      areaName: 'Borivali',
      joiningDate: DateTime(2023, 11, 20),
      bloodGroup: 'O-',
      lastKnownLatitude: 19.2307,
      lastKnownLongitude: 72.8567,
      lastSeenAt: today.add(const Duration(hours: 8, minutes: 55)),
    ),
    Employee(
      id: 'emp-10',
      employeeCode: 'ASM201',
      name: 'Ramesh Iyer',
      role: UserRole.asm,
      designation: 'Area Sales Manager',
      mobile: '9820011000',
      email: 'ramesh.iyer@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'Mumbai South',
      headquarters: 'Mumbai',
      managerId: 'emp-20',
      managerName: 'Kavita Rao',
      joiningDate: DateTime(2017, 2, 6),
      bloodGroup: 'B-',
    ),
    Employee(
      id: 'emp-20',
      employeeCode: 'RSM301',
      name: 'Kavita Rao',
      role: UserRole.rsm,
      designation: 'Regional Sales Manager',
      mobile: '9810022000',
      email: 'kavita.rao@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'West Region',
      headquarters: 'Mumbai',
      managerId: 'emp-30',
      managerName: 'Arun Mehta',
      joiningDate: DateTime(2014, 7, 21),
    ),
    Employee(
      id: 'emp-30',
      employeeCode: 'NSM401',
      name: 'Arun Mehta',
      role: UserRole.nsm,
      designation: 'National Sales Manager',
      mobile: '9800033000',
      email: 'arun.mehta@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'India',
      headquarters: 'Mumbai',
      joiningDate: DateTime(2011, 3, 14),
    ),
    Employee(
      id: 'emp-99',
      employeeCode: 'ADM001',
      name: 'System Administrator',
      role: UserRole.admin,
      designation: 'System Owner',
      mobile: '9800000000',
      email: 'admin@pharmaconnect.in',
      territoryId: 'ter-1',
      territoryName: 'All',
      headquarters: 'Mumbai',
    ),
  ];

  /// Every employee reachable from [rootId], inclusive. Walks the reporting
  /// tree so a manager's queries automatically cover indirect reports.
  List<Employee> subtreeOf(String rootId) {
    final result = <Employee>[];
    final queue = <String>[rootId];

    while (queue.isNotEmpty) {
      final id = queue.removeAt(0);
      final employee = employees.where((e) => e.id == id).firstOrNull;
      if (employee == null) continue;
      result.add(employee);
      queue.addAll(
        employees.where((e) => e.managerId == id).map((e) => e.id),
      );
    }
    return result;
  }

  // ============================================================= catalogue ==

  late final List<Product> products = const [
    Product(
      id: 'p-1',
      name: 'Cardiovex 40',
      code: 'CVX40',
      mrp: 650,
      division: 'Cardiology',
      composition: 'Atorvastatin 40mg',
      packSize: '10 tablets',
      gstPercent: 12,
    ),
    Product(
      id: 'p-2',
      name: 'Neurokind Plus',
      code: 'NKP',
      mrp: 160,
      division: 'Neurology',
      composition: 'Methylcobalamin + ALA',
      packSize: '10 capsules',
      gstPercent: 12,
    ),
    Product(
      id: 'p-3',
      name: 'Vitapro D3',
      code: 'VPD3',
      mrp: 400,
      division: 'Nutrition',
      composition: 'Cholecalciferol 60000 IU',
      packSize: '4 sachets',
      gstPercent: 5,
    ),
    Product(
      id: 'p-4',
      name: 'Respiclear 200',
      code: 'RSC200',
      mrp: 285,
      division: 'Respiratory',
      composition: 'Acebrophylline 200mg',
      packSize: '10 tablets',
      gstPercent: 12,
    ),
    Product(
      id: 'p-5',
      name: 'Gastrolyte DSR',
      code: 'GLDSR',
      mrp: 195,
      division: 'Gastroenterology',
      composition: 'Pantoprazole + Domperidone',
      packSize: '10 capsules',
      gstPercent: 12,
    ),
    Product(
      id: 'p-6',
      name: 'Cardiovex 20',
      code: 'CVX20',
      mrp: 420,
      division: 'Cardiology',
      composition: 'Atorvastatin 20mg',
      packSize: '10 tablets',
      gstPercent: 12,
    ),
    Product(
      id: 'p-7',
      name: 'Glucomet XR 1000',
      code: 'GMX1000',
      mrp: 240,
      division: 'Diabetology',
      composition: 'Metformin SR 1000mg',
      packSize: '15 tablets',
      gstPercent: 12,
    ),
    Product(
      id: 'p-8',
      name: 'Ostecal K2',
      code: 'OSTK2',
      mrp: 355,
      division: 'Orthopaedics',
      composition: 'Calcium Citrate + Vitamin K2-7',
      packSize: '15 tablets',
      gstPercent: 12,
    ),
    Product(
      id: 'p-9',
      name: 'Femiron XT',
      code: 'FMXT',
      mrp: 285,
      division: 'Gynaecology',
      composition: 'Ferrous Ascorbate + Folic Acid',
      packSize: '10 tablets',
      gstPercent: 5,
    ),
    Product(
      id: 'p-10',
      name: 'Pediacef 50 DS',
      code: 'PDC50',
      mrp: 130,
      division: 'Paediatrics',
      composition: 'Cefixime Dry Syrup 50mg',
      packSize: '30 ml bottle',
      gstPercent: 5,
    ),
    Product(
      id: 'p-11',
      name: 'Neurokind Gold',
      code: 'NKG',
      mrp: 310,
      division: 'Neurology',
      composition: 'Methylcobalamin + Pregabalin',
      packSize: '10 capsules',
      gstPercent: 12,
    ),
    Product(
      id: 'p-12',
      name: 'Respiclear LM Kid',
      code: 'RSCLM',
      mrp: 165,
      division: 'Respiratory',
      composition: 'Montelukast + Levocetirizine',
      packSize: '10 tablets',
      gstPercent: 12,
    ),
  ];

  static const _specialties = [
    'Cardiologist',
    'Physician',
    'Gynecologist',
    'Neurologist',
    'Pediatrician',
    'Orthopedic',
    'Diabetologist',
    'Pulmonologist',
  ];

  // =============================================================== clients ==

  late final List<Client> clients = _buildClients();

  List<Client> _buildClients() {
    const names = [
      'Dr. Anjali Sharma',
      'Dr. Mohan Singh',
      'Dr. Priya Nair',
      'Dr. Rahul Mehta',
      'Dr. Sanjay Gupta',
      'Dr. Meera Joshi',
      'Dr. Kiran Bedi',
      'Dr. Arvind Rao',
      'Dr. Nisha Verma',
      'Dr. Farhan Ali',
      'Dr. Sunita Kulkarni',
      'Dr. Rajesh Pillai',
      'Dr. Vandana Iyer',
      'Dr. Ashok Deshpande',
      'Dr. Leela Menon',
      'Dr. Suresh Bhatt',
      'Dr. Ritu Chawla',
      'Dr. Naveen Kamath',
      'Dr. Shalini Prabhu',
      'Dr. Zoya Khan',
    ];
    const facilities = [
      'Apollo Clinic',
      'Lilavati Hospital',
      'Fortis Healthcare',
      'Nanavati Max',
      'Holy Family Hospital',
      'Kokilaben Hospital',
      'Hinduja Hospital',
      'Bombay Hospital',
      'Jaslok Hospital',
      'Breach Candy Hospital',
    ];
    const chemists = [
      'Wellness Forever',
      'Apollo Pharmacy',
      'MedPlus Andheri',
      'Noble Chemists',
      'Sanjivani Medical',
      'Shree Krishna Chemist',
      'LifeCare Pharmacy',
      'Guardian Pharmacy',
      'Trust Chemist',
      'Om Sai Medical',
    ];

    const stockists = [
      'Mahavir Pharma Distributors',
      'Sai Medical Agencies',
      'Western Drug House',
      'Deepak Pharma Distributors',
      'Konark Healthcare Supplies',
    ];

    final result = <Client>[];
    // Mumbai city centre, spread across a realistic few kilometres.
    const baseLat = 19.1136;
    const baseLng = 72.8697;

    // Scatter clients in two dimensions. An earlier version offset lat and lng
    // by the same index, which put every client on a perfect diagonal — fine in
    // a list, instantly fake the moment they are plotted on a map. The offsets
    // are derived from the index rather than an RNG so positions stay stable
    // across runs.
    (double, double) scatter(int i, double spread) {
      final a = math.sin(i * 2.399963) * spread; // golden-angle walk
      final b = math.cos(i * 1.618034) * spread;
      final radius = 0.35 + ((i * 37) % 100) / 100 * 0.65;
      return (a * radius, b * radius);
    }

    for (var i = 0; i < names.length; i++) {
      final area = areas[i % 3];
      result.add(
        Client(
          id: 'cli-${i + 1}',
          name: names[i],
          type: ClientType.doctor,
          category: ClientCategory.values[i % 3],
          areaId: area.id,
          areaName: area.name,
          territoryId: area.territoryId,
          specialty: _specialties[i % _specialties.length],
          designation: 'Consultant',
          contactPerson: names[i],
          mobile: '98${(76543210 + i * 137).toString().padLeft(8, '0')}',
          email: 'contact${i + 1}@clinic.in',
          addressLine: '${facilities[i % facilities.length]}, Wing A',
          city: 'Mumbai',
          pincode: '4000${(53 + i % 9).toString().padLeft(2, '0')}',
          latitude: baseLat + scatter(i, 0.020).$1,
          longitude: baseLng + scatter(i, 0.020).$2,
          clusterId: clusters[i % clusters.length].id,
          clusterName: clusters[i % clusters.length].name,
          lastVisitAt: today.subtract(Duration(days: 2 + i * 3)),
          totalVisits: 4 + (i * 3) % 17,
          ownerEmployeeId: employees[i % 5].id,
          createdAt: today.subtract(Duration(days: 120 + i * 11)),
        ),
      );
    }

    for (var i = 0; i < facilities.length; i++) {
      final area = areas[i % areas.length];
      result.add(
        Client(
          id: 'cli-h${i + 1}',
          name: facilities[i],
          type: ClientType.hospital,
          category: i.isEven ? ClientCategory.coreTarget : ClientCategory.regular,
          areaId: area.id,
          areaName: area.name,
          territoryId: area.territoryId,
          specialty: 'Multi-speciality',
          contactPerson: 'Purchase Desk',
          mobile: '022${(24451100 + i * 7).toString()}',
          addressLine: '${facilities[i]} Main Building',
          city: 'Mumbai',
          pincode: '4000${(58 + i).toString().padLeft(2, '0')}',
          latitude: baseLat + scatter(i + 40, 0.024).$1,
          longitude: baseLng + scatter(i + 40, 0.024).$2,
          lastVisitAt: today.subtract(Duration(days: 5 + i * 4)),
          totalVisits: 9 + i * 2,
          ownerEmployeeId: employees[i % 5].id,
          createdAt: today.subtract(Duration(days: 300 + i * 20)),
        ),
      );
    }

    for (var i = 0; i < chemists.length; i++) {
      final area = areas[i % areas.length];
      result.add(
        Client(
          id: 'cli-c${i + 1}',
          name: chemists[i],
          type: ClientType.chemist,
          category: ClientCategory.regular,
          areaId: area.id,
          areaName: area.name,
          territoryId: area.territoryId,
          contactPerson: 'Store Manager',
          mobile: '99${(30011220 + i * 91).toString()}',
          addressLine: '${chemists[i]}, Ground Floor',
          city: 'Mumbai',
          pincode: '400062',
          latitude: baseLat + scatter(i + 80, 0.016).$1,
          longitude: baseLng + scatter(i + 80, 0.016).$2,
          lastVisitAt: today.subtract(Duration(days: 1 + i * 2)),
          totalVisits: 12 + i * 3,
          ownerEmployeeId: employees[i % 5].id,
          createdAt: today.subtract(Duration(days: 200 + i * 15)),
        ),
      );
    }

    // Stockists complete the trade channel: orders in this business flow
    // through distributors, so a demo without them is missing a link.
    for (var i = 0; i < stockists.length; i++) {
      final area = areas[i % areas.length];
      result.add(
        Client(
          id: 'cli-s${i + 1}',
          name: stockists[i],
          type: ClientType.stockist,
          category:
              i.isEven ? ClientCategory.coreTarget : ClientCategory.regular,
          areaId: area.id,
          areaName: area.name,
          territoryId: area.territoryId,
          contactPerson: 'Distribution Head',
          mobile: '98${(20033440 + i * 73).toString()}',
          email: 'orders${i + 1}@distributor.in',
          addressLine: '${stockists[i]}, Warehouse Block',
          city: 'Mumbai',
          pincode: '4000${(70 + i).toString().padLeft(2, '0')}',
          latitude: baseLat + scatter(i + 120, 0.026).$1,
          longitude: baseLng + scatter(i + 120, 0.026).$2,
          lastVisitAt: today.subtract(Duration(days: 3 + i * 5)),
          totalVisits: 18 + i * 4,
          // One stockist per rep, so every rep can raise a distributor order.
          ownerEmployeeId: employees[i % 5].id,
          createdAt: today.subtract(Duration(days: 400 + i * 30)),
        ),
      );
    }

    return result;
  }

  // ============================================================ activities ==

  late final List<Activity> activities = _buildActivities();

  /// Builds ~8 weeks of history plus today's plan for every MR.
  ///
  /// Today's schedule for the demo user is deliberately mid-progress — some
  /// completed, one imminent — because Home is only meaningful when there is a
  /// genuine "next action" to show (§15).
  List<Activity> _buildActivities() {
    final result = <Activity>[];
    final mrs = employees.where((e) => e.role == UserRole.mr).toList();
    var counter = 0;

    // Field-facing managers ride along on joint calls, so they have a real —
    // if lighter — schedule of their own. Without this their day plan,
    // activity feed and attendance all read as empty or absent.
    final schedules = <(Employee, int)>[
      for (final mr in mrs) (mr, 0),
      for (final manager in fieldManagers)
        (manager, manager.role == UserRole.asm ? 3 : 2),
    ];

    for (final (mr, managerVisits) in schedules) {
      final isManager = managerVisits > 0;

      // A manager works across the whole team's client base, not a personal
      // list, so they draw from every client in their territory.
      final mrClients = isManager
          ? clients.take(14).toList()
          : clients.where((c) => c.ownerEmployeeId == mr.id).toList();
      if (mrClients.isEmpty) continue;

      for (var dayOffset = -56; dayOffset <= 6; dayOffset++) {
        final date = today.add(Duration(days: dayOffset));
        if (date.weekday == DateTime.sunday) continue;

        // Managers are in the field roughly every other day; the rest is
        // office and review work.
        if (isManager && (dayOffset + date.day) % 2 != 0) continue;

        final visitCount = isManager
            ? managerVisits
            : dayOffset == 0
                ? (mr.id == 'emp-1' ? _todayVisitCount : 6 + _rng.nextInt(3))
                : 5 + _rng.nextInt(5);

        for (var i = 0; i < visitCount; i++) {
          final client = mrClients[(counter + i) % mrClients.length];
          final start = date.add(Duration(minutes: 9 * 60 + i * 45));
          final end = start.add(const Duration(minutes: 15));

          final status = _statusFor(
            dayOffset: dayOffset,
            index: i,
            visitCount: visitCount,
          );

          final isDone = status == ActivityStatus.completed;
          final geo = isDone ? _geoFor(client, i) : null;

          result.add(
            Activity(
              id: 'act-${++counter}',
              employeeId: mr.id,
              employeeName: mr.name,
              clientId: client.id,
              clientName: client.name,
              clientSpecialty: client.specialty,
              clientType: client.type,
              locationName: client.addressLine,
              areaName: client.areaName,
              scheduledStart: start,
              scheduledEnd: end,
              actualStart: isDone ? start.add(const Duration(minutes: 2)) : null,
              actualEnd: isDone ? end.add(const Duration(minutes: 3)) : null,
              status: status,
              purpose: VisitPurpose.values[(counter + i) % VisitPurpose.values.length],
              contactPerson: client.contactPerson,
              contactMobile: client.mobile,
              feedback: isDone
                  ? 'Discussed new product benefits and dosage schedule. '
                      'Doctor responded positively to the clinical data.'
                  : null,
              pop: isDone ? 'Shared visual aid & product brochure.' : null,
              remarks: isDone ? 'Sample provided.' : null,
              rcpaScore: isDone ? 3 + (counter % 3) : null,
              rcpaEntries: isDone ? _rcpaFor(counter) : const [],
              productIds: isDone
                  ? [products[counter % products.length].id]
                  : const [],
              expectedNextVisit:
                  isDone ? date.add(const Duration(days: 21)) : null,
              geoResult: geo,
              outOfRangeReason: geo?.requiresReason == true
                  ? 'Doctor asked to meet at the adjacent OPD block.'
                  : null,
              createdAt: start,
              updatedAt: isDone ? end : start,
            ),
          );
        }
      }
    }

    return result;
  }

  ActivityStatus _statusFor({
    required int dayOffset,
    required int index,
    required int visitCount,
  }) {
    if (dayOffset > 0) return ActivityStatus.planned;

    if (dayOffset == 0) {
      // Today's progress tracks the actual clock rather than a fixed count.
      // A hardcoded "3 of 10 done" reads as broken at 9am and as hopelessly
      // behind at 6pm; deriving it from the elapsed working day means the
      // app looks plausible whenever the demo is given.
      //
      // Slightly ahead of a pure pro-rata so the demo user reads as "on track"
      // rather than permanently behind their own plan.
      final elapsed = _elapsedWorkingDayFraction();

      // Clamped at both ends on purpose. Home is only meaningful when there is
      // a next action to show and some progress behind it, so the demo always
      // keeps at least two visits done and three still ahead — whatever time
      // of day it is opened.
      // Clamped against *this rep's* visit count, not the demo user's. Using a
      // fixed constant here left every other rep with a fully-completed day and
      // no next action — Home's whole purpose — because they are scheduled
      // fewer visits.
      final done = (visitCount * elapsed * 1.05)
          .floor()
          .clamp(1, (visitCount - 3).clamp(1, visitCount));

      if (index < done) return ActivityStatus.completed;
      if (index == done) return ActivityStatus.upcoming;
      return ActivityStatus.planned;
    }

    // History: mostly completed, with a believable miss rate.
    final roll = _rng.nextInt(100);
    if (roll < 84) return ActivityStatus.completed;
    if (roll < 93) return ActivityStatus.missed;
    return ActivityStatus.rescheduled;
  }

  /// Visits scheduled for the demo user today. Kept as a named constant so the
  /// status generator and the schedule builder cannot drift apart.
  static const int _todayVisitCount = 10;

  /// How much of a 9am–6pm working day has elapsed, clamped to [0, 1].
  double _elapsedWorkingDayFraction() {
    final now = DateTime.now();
    final hour = now.hour + now.minute / 60;
    return ((hour - 9) / 9).clamp(0.0, 1.0);
  }

  /// Most completed visits verify cleanly; roughly one in seven lands out of
  /// range, which is what real field data looks like and exercises the
  /// unverified-visit treatment throughout the UI.
  GeoFenceResult _geoFor(Client client, int index) {
    final registered = client.location;
    if (registered == null) return GeoFenceResult.unavailable;

    final isOutOfRange = index % 7 == 5;
    final offset = isOutOfRange ? 0.0009 : 0.00022;

    final captured = GeoPoint(
      registered.latitude + offset,
      registered.longitude + offset * 0.4,
    );

    return GeoMath.evaluate(
      captured: captured,
      registered: registered,
      capturedAt: DateTime.now(),
    );
  }

  List<RcpaEntry> _rcpaFor(int seed) {
    final product = products[seed % products.length];
    return [
      RcpaEntry(
        productId: product.id,
        productName: product.name,
        ownQuantity: 4 + seed % 8,
        competitorName: 'Competitor ${String.fromCharCode(65 + seed % 3)}',
        competitorQuantity: 3 + (seed * 2) % 7,
      ),
    ];
  }

  // ============================================================== field ops ==

  /// Everyone who files expenses, leave and tour plans — that is every
  /// employee except the system owner. Managers were previously excluded,
  /// which left their Expenses, Travel and Leave screens completely empty.
  late final List<Employee> fieldForce =
      employees.where((e) => e.role != UserRole.admin).toList();

  /// Managers who still do field work: an ASM runs joint calls with their reps
  /// and an RSM does market visits, so both have a real day plan. An NSM does
  /// not, and seeding them one would be fiction.
  late final List<Employee> fieldManagers = employees
      .where((e) => e.role == UserRole.asm || e.role == UserRole.rsm)
      .toList();

  late final List<Expense> expenses = _buildExpenses();

  List<Expense> _buildExpenses() {
    final result = <Expense>[];
    final mrs = fieldForce;
    var n = 0;

    const descriptions = {
      ExpenseCategory.travel: 'Local conveyance for field visits',
      ExpenseCategory.food: 'Working lunch during field work',
      ExpenseCategory.lodging: 'Overnight stay — outstation tour',
      ExpenseCategory.fuel: 'Fuel top-up for two-wheeler',
      ExpenseCategory.other: 'Doctor meeting refreshments',
    };

    for (final mr in mrs) {
      for (var dayOffset = -45; dayOffset <= 0; dayOffset += 2) {
        final date = today.add(Duration(days: dayOffset));
        if (date.weekday == DateTime.sunday) continue;

        final category =
            ExpenseCategory.values[n % ExpenseCategory.values.length];
        final amount = switch (category) {
          ExpenseCategory.travel => 250.0 + (n % 8) * 50,
          ExpenseCategory.food => 180.0 + (n % 6) * 40,
          ExpenseCategory.lodging => 1200.0 + (n % 4) * 250,
          ExpenseCategory.fuel => 400.0 + (n % 5) * 60,
          ExpenseCategory.other => 300.0 + (n % 7) * 45,
        };

        // Recent claims are still moving through approval; older ones settled.
        final status = dayOffset > -4
            ? ApprovalStatus.draft
            : dayOffset > -10
                ? ApprovalStatus.submitted
                : (n % 11 == 0 ? ApprovalStatus.rejected : ApprovalStatus.approved);

        result.add(
          Expense(
            id: 'exp-${++n}',
            employeeId: mr.id,
            employeeName: mr.name,
            date: date,
            category: category,
            amount: amount,
            status: status,
            description: descriptions[category],
            remarks: category == ExpenseCategory.travel
                ? '${mr.areaName} — 4 client visits'
                : null,
            receiptPaths: status == ApprovalStatus.draft ? const [] : const ['receipt'],
            travelMode: category == ExpenseCategory.travel ? TravelMode.auto : null,
            fromLocation: category == ExpenseCategory.travel ? mr.headquarters : null,
            toLocation: category == ExpenseCategory.travel ? mr.areaName : null,
            distanceKm: category == ExpenseCategory.travel ? 12.0 + n % 9 : null,
            approvalHistory: _historyFor(status, mr, date, amount),
            createdAt: date,
          ),
        );
      }
    }
    return result;
  }

  List<ApprovalEvent> _historyFor(
    ApprovalStatus status,
    Employee employee,
    DateTime date,
    double amount,
  ) {
    if (status == ApprovalStatus.draft) return const [];

    // The top of the hierarchy has no manager above them; their claims are
    // settled by head office rather than a person in this list.
    final manager = employees
        .where((e) => e.id == employee.managerId)
        .firstOrNull;
    final approverName = manager?.name ?? 'Head Office';
    final approverId = manager?.id ?? 'head-office';
    final approverRole = manager?.role.shortLabel ?? 'HO';
    final events = <ApprovalEvent>[
      ApprovalEvent(
        status: ApprovalStatus.submitted,
        actorId: employee.id,
        actorName: employee.name,
        actorRole: employee.role.shortLabel,
        at: date.add(const Duration(hours: 19)),
      ),
    ];

    if (status.isDecided) {
      events.add(
        ApprovalEvent(
          status: status,
          actorId: approverId,
          actorName: approverName,
          actorRole: approverRole,
          at: date.add(const Duration(days: 1, hours: 11)),
          reason: status == ApprovalStatus.rejected
              ? 'Receipt is not legible. Please re-upload a clear photograph.'
              : null,
          comment: status == ApprovalStatus.approved ? 'Approved as per policy.' : null,
        ),
      );
    }
    return events;
  }

  late final List<TravelPlan> travelPlans = _buildTravelPlans();

  List<TravelPlan> _buildTravelPlans() {
    final result = <TravelPlan>[];
    // Everyone tours, including the national manager — theirs are outstation
    // rather than local, but they still file a plan.
    final mrs = fieldForce;
    var n = 0;

    for (final mr in mrs) {
      for (var dayOffset = -14; dayOffset <= 24; dayOffset += 3) {
        final date = today.add(Duration(days: dayOffset));
        if (date.weekday == DateTime.sunday) continue;

        final area = areas[n % areas.length];
        final status = dayOffset < -2
            ? ApprovalStatus.approved
            : dayOffset < 4
                ? ApprovalStatus.submitted
                : (n % 5 == 0 ? ApprovalStatus.draft : ApprovalStatus.submitted);

        result.add(
          TravelPlan(
            id: 'tp-${++n}',
            employeeId: mr.id,
            employeeName: mr.name,
            date: date,
            workType: WorkType.fieldWork,
            status: status,
            areaId: area.id,
            areaName: area.name,
            territoryName: mr.territoryName,
            tourType: n % 6 == 0 ? TourType.outstation : TourType.local,
            travelMode: n % 6 == 0 ? TravelMode.train : TravelMode.bike,
            destination: area.name,
            purpose: 'Routine coverage and RCPA in ${area.name}',
            plannedVisits: 6 + n % 5,
            estimatedKm: 14.0 + (n % 11) * 3,
            approvalHistory: _historyFor(status, mr, date, 0),
            createdAt: date.subtract(const Duration(days: 3)),
          ),
        );
      }
    }
    return result;
  }

  late final List<LeaveRequest> leaveRequests = _buildLeaves();

  List<LeaveRequest> _buildLeaves() {
    final mrs = fieldForce;
    const reasons = [
      'Personal work',
      'Family function',
      'Medical — viral fever',
      'Attending a relative’s wedding',
    ];

    final result = <LeaveRequest>[];
    var n = 0;

    for (final mr in mrs) {
      for (var i = 0; i < 3; i++) {
        final from = today.add(Duration(days: -30 + i * 16 + n));
        final status = i == 2
            ? ApprovalStatus.submitted
            : (n % 7 == 0 ? ApprovalStatus.rejected : ApprovalStatus.approved);

        result.add(
          LeaveRequest(
            id: 'lv-${++n}',
            employeeId: mr.id,
            employeeName: mr.name,
            fromDate: from,
            toDate: from.add(Duration(days: i % 3)),
            type: LeaveType.values[n % LeaveType.values.length],
            reason: reasons[n % reasons.length],
            status: status,
            approvalHistory: _historyFor(status, mr, from, 0),
            createdAt: from.subtract(const Duration(days: 5)),
          ),
        );
      }
    }
    return result;
  }

  late final List<Holiday> holidays = [
    Holiday(id: 'h-1', name: 'Republic Day', date: DateTime(today.year, 1, 26)),
    Holiday(id: 'h-2', name: 'Holi', date: DateTime(today.year, 3, 14)),
    Holiday(id: 'h-3', name: 'Good Friday', date: DateTime(today.year, 4, 18)),
    Holiday(id: 'h-4', name: 'Independence Day', date: DateTime(today.year, 8, 15)),
    Holiday(id: 'h-5', name: 'Gandhi Jayanti', date: DateTime(today.year, 10, 2)),
    Holiday(id: 'h-6', name: 'Diwali', date: DateTime(today.year, 11, 8)),
    Holiday(id: 'h-7', name: 'Christmas', date: DateTime(today.year, 12, 25)),
    Holiday(
        id: 'h-8',
        name: 'Maharashtra Day',
        date: DateTime(today.year, 5, 1)),
    Holiday(
        id: 'h-9',
        name: 'Ganesh Chaturthi',
        date: DateTime(today.year, 9, 14)),
    Holiday(id: 'h-10', name: 'Dussehra', date: DateTime(today.year, 10, 21)),
    Holiday(
        id: 'h-11',
        name: 'Id-e-Milad',
        date: DateTime(today.year, 8, 26),
        isOptional: true),
    Holiday(
        id: 'h-12',
        name: 'Guru Nanak Jayanti',
        date: DateTime(today.year, 11, 24),
        isOptional: true),
  ];

  late final List<Payslip> payslips = [
    // Twelve months so the payslip list scrolls like a real record. Incentive
    // varies by month — a salary that is identical every month looks synthetic.
    for (var i = 0; i < 12; i++)
      () {
        final incentive = 3000.0 + ((i * 37) % 9) * 750;
        final gross = 58000.0 + incentive;
        return Payslip(
          id: 'ps-$i',
          month: DateTime(today.year, today.month - i, 1),
          grossPay: gross,
          deductions: 8400,
          earnings: {
            'Basic': 31000,
            'HRA': 12400,
            'Conveyance': 6000,
            'Field Allowance': 8600,
            'Incentive': incentive,
          },
          deductionBreakup: const {
            'Provident Fund': 3720,
            'Professional Tax': 200,
            'TDS': 4480,
          },
        );
      }(),
  ];

  late final List<AppDocument> documents = [
    AppDocument(
      id: 'doc-1',
      name: 'Appointment Letter',
      type: 'PDF',
      uploadedAt: DateTime(2022, 4, 11),
      sizeLabel: '210 KB',
      category: 'Employment',
    ),
    AppDocument(
      id: 'doc-2',
      name: 'Form 16 — FY 2025-26',
      type: 'PDF',
      uploadedAt: today.subtract(const Duration(days: 120)),
      sizeLabel: '480 KB',
      category: 'Tax',
    ),
    AppDocument(
      id: 'doc-3',
      name: 'Expense Policy v4',
      type: 'PDF',
      uploadedAt: today.subtract(const Duration(days: 40)),
      sizeLabel: '1.2 MB',
      category: 'Policy',
    ),
    AppDocument(
      id: 'doc-4',
      name: 'Insurance Card',
      type: 'IMG',
      uploadedAt: today.subtract(const Duration(days: 300)),
      sizeLabel: '640 KB',
      category: 'Benefits',
    ),
    AppDocument(
      id: 'doc-5',
      name: 'Increment Letter — FY 2026',
      type: 'PDF',
      uploadedAt: today.subtract(const Duration(days: 145)),
      sizeLabel: '180 KB',
      category: 'Employment',
    ),
    AppDocument(
      id: 'doc-6',
      name: 'Travel & Expense Policy v4',
      type: 'PDF',
      uploadedAt: today.subtract(const Duration(days: 40)),
      sizeLabel: '890 KB',
      category: 'Policy',
    ),
    AppDocument(
      id: 'doc-7',
      name: 'Mediclaim Policy Document',
      type: 'PDF',
      uploadedAt: today.subtract(const Duration(days: 210)),
      sizeLabel: '1.6 MB',
      category: 'Benefits',
    ),
    AppDocument(
      id: 'doc-8',
      name: 'PAN Card',
      type: 'IMG',
      uploadedAt: today.subtract(const Duration(days: 420)),
      sizeLabel: '320 KB',
      category: 'Identity',
    ),
    AppDocument(
      id: 'doc-9',
      name: 'Code of Conduct — Signed',
      type: 'PDF',
      uploadedAt: today.subtract(const Duration(days: 365)),
      sizeLabel: '240 KB',
      category: 'Compliance',
    ),
  ];

  late final List<Resource> resources = [
    Resource(
      id: 'res-1',
      title: 'Cardiovex 40 — Visual Aid',
      category: 'E-Detailing',
      updatedAt: today.subtract(const Duration(days: 6)),
      description: 'Clinical evidence deck for the cardiology range.',
      sizeLabel: '4.2 MB',
      productId: 'p-1',
    ),
    Resource(
      id: 'res-2',
      title: 'Neurokind Plus — Product Monograph',
      category: 'Product Information',
      updatedAt: today.subtract(const Duration(days: 14)),
      description: 'Composition, indications and dosage guidance.',
      sizeLabel: '1.8 MB',
      productId: 'p-2',
    ),
    Resource(
      id: 'res-3',
      title: 'Price List — Effective 1 Aug',
      category: 'Price List',
      updatedAt: today.subtract(const Duration(days: 26)),
      description: 'Current MRP, PTS and PTR across all divisions.',
      sizeLabel: '320 KB',
    ),
    Resource(
      id: 'res-4',
      title: 'Objection Handling — Field Training',
      category: 'Training',
      updatedAt: today.subtract(const Duration(days: 3)),
      description: 'Common doctor objections and evidence-backed responses.',
      sizeLabel: '12 MB',
      fileType: 'VIDEO',
    ),
    Resource(
      id: 'res-5',
      title: 'Respiclear 200 — Sample Request Form',
      category: 'Document',
      updatedAt: today.subtract(const Duration(days: 33)),
      sizeLabel: '96 KB',
      productId: 'p-4',
    ),
    Resource(
      id: 'res-6',
      title: 'Glucomet XR — Visual Aid',
      category: 'E-Detailing',
      updatedAt: today.subtract(const Duration(days: 9)),
      description: 'Titration guidance and HbA1c outcome data.',
      sizeLabel: '3.6 MB',
      productId: 'p-7',
    ),
    Resource(
      id: 'res-7',
      title: 'Femiron XT — Product Monograph',
      category: 'Product Information',
      updatedAt: today.subtract(const Duration(days: 21)),
      description: 'Iron absorption profile and tolerability data.',
      sizeLabel: '2.1 MB',
      productId: 'p-9',
    ),
    Resource(
      id: 'res-8',
      title: 'RCPA — How to Run a Chemist Audit',
      category: 'Training',
      updatedAt: today.subtract(const Duration(days: 12)),
      description: 'Step-by-step method for a reliable prescription audit.',
      sizeLabel: '18 MB',
      fileType: 'VIDEO',
    ),
    Resource(
      id: 'res-9',
      title: 'Pediacef 50 DS — Dosage Chart',
      category: 'Product Information',
      updatedAt: today.subtract(const Duration(days: 5)),
      description: 'Weight-band dosing reference for paediatric use.',
      sizeLabel: '440 KB',
      productId: 'p-10',
    ),
    Resource(
      id: 'res-10',
      title: 'Hospital Tender — Documentation Checklist',
      category: 'Document',
      updatedAt: today.subtract(const Duration(days: 17)),
      description: 'Everything required before submitting an institutional bid.',
      sizeLabel: '210 KB',
    ),
    Resource(
      id: 'res-11',
      title: 'Ostecal K2 — Clinical Evidence Deck',
      category: 'E-Detailing',
      updatedAt: today.subtract(const Duration(days: 2)),
      description: 'Bone mineral density trial summaries.',
      sizeLabel: '5.4 MB',
      productId: 'p-8',
    ),
    Resource(
      id: 'res-12',
      title: 'Code of Conduct — Field Interactions',
      category: 'Training',
      updatedAt: today.subtract(const Duration(days: 48)),
      description: 'Compliance rules for doctor and chemist engagement.',
      sizeLabel: '760 KB',
    ),
  ];

  // =============================================================== business ==

  late final List<Order> orders = _buildOrders();

  List<Order> _buildOrders() {
    final result = <Order>[];
    final mrs = employees.where((e) => e.role == UserRole.mr).toList();
    var n = 0;

    for (final mr in mrs) {
      final mrClients = clients
          .where((c) => c.ownerEmployeeId == mr.id && c.type != ClientType.doctor)
          .toList();
      if (mrClients.isEmpty) continue;

      for (var i = 0; i < 5; i++) {
        final client = mrClients[i % mrClients.length];
        final date = today.subtract(Duration(days: i * 3 + n % 4));
        n++;

        final items = [
          for (var j = 0; j < 2 + i % 3; j++)
            () {
              final product = products[(n + j) % products.length];
              return OrderItem(
                productId: product.id,
                productName: product.name,
                rate: product.mrp,
                quantity: 5 + ((n + j) % 4) * 5,
                discountPercent: [0.0, 5.0, 7.5, 10.0][(n + j) % 4],
                gstPercent: product.gstPercent,
                freeQuantity: (n + j) % 5 == 0 ? 2 : 0,
                packSize: product.packSize,
              );
            }(),
        ];

        final status = i == 0
            ? ApprovalStatus.pending
            : i == 1
                ? ApprovalStatus.submitted
                : (n % 9 == 0 ? ApprovalStatus.rejected : ApprovalStatus.approved);

        result.add(
          Order(
            id: 'ord-$n',
            orderNumber: 'ORD-${1000 + n}',
            employeeId: mr.id,
            employeeName: mr.name,
            clientId: client.id,
            clientName: client.name,
            date: date,
            status: status,
            items: items,
            remarks: i == 0 ? 'Urgent — stock required before month end.' : null,
            approvalHistory: _historyFor(status, mr, date, 0),
            expectedDelivery: date.add(const Duration(days: 5)),
          ),
        );
      }
    }
    return result;
  }

  late final List<Target> targets = _buildTargets();

  /// Targets for the trailing twelve months. Achievement is *derived from
  /// orders* for the current month so the Business dashboard and the Orders
  /// list can never disagree.
  List<Target> _buildTargets() {
    final result = <Target>[];
    final mrs = employees.where((e) => e.role == UserRole.mr).toList();
    var n = 0;

    for (final mr in mrs) {
      for (var monthsBack = 11; monthsBack >= 0; monthsBack--) {
        final month = DateTime(today.year, today.month - monthsBack, 1);
        final targetAmount = 600000.0 + (n % 4) * 25000;

        // For the current month, achievement is month-to-date, not a full
        // month's worth: pro-rate the run-rate by how much of the month has
        // elapsed, then add the orders actually captured in the app. Using
        // in-app orders alone would show every rep at single-digit
        // achievement, which reads as a broken app rather than an early month.
        final achieved = monthsBack == 0
            ? _monthToDateSales(mr.id, month, targetAmount, n)
            : targetAmount * (0.62 + ((n * 7 + monthsBack * 13) % 55) / 100);

        result.add(
          Target(
            id: 'tgt-${++n}',
            employeeId: mr.id,
            employeeName: mr.name,
            month: month,
            targetAmount: targetAmount,
            achievedAmount: achieved,
            areaId: mr.areaId,
            areaName: mr.areaName,
            visitTarget: 132,
            visitsAchieved: monthsBack == 0
                ? _monthVisitCount(mr.id, month)
                : 96 + (n * 5) % 40,
          ),
        );
      }
    }
    return result;
  }

  /// Month-to-date sales for the running month.
  ///
  /// Pro-rates the employee's run-rate across the elapsed portion of the month
  /// and adds the value of orders captured in the app, so the figure moves as
  /// the demo user places orders while still being plausible on day one.
  double _monthToDateSales(
    String employeeId,
    DateTime month,
    double targetAmount,
    int seed,
  ) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final elapsed = (today.day / daysInMonth).clamp(0.0, 1.0);

    // Per-employee performance factor, deterministic and spread around target.
    final factor = 0.72 + ((seed * 11) % 45) / 100;

    return targetAmount * elapsed * factor + _monthOrderValue(employeeId, month);
  }

  double _monthOrderValue(String employeeId, DateTime month) {
    return orders
        .where((o) =>
            o.employeeId == employeeId &&
            o.date.year == month.year &&
            o.date.month == month.month &&
            o.status != ApprovalStatus.rejected)
        .fold<double>(0, (sum, o) => sum + o.grandTotal);
  }

  int _monthVisitCount(String employeeId, DateTime month) {
    return activities
        .where((a) =>
            a.employeeId == employeeId &&
            a.status == ActivityStatus.completed &&
            a.scheduledStart.year == month.year &&
            a.scheduledStart.month == month.month)
        .length;
  }

  late final List<SalesRecord> salesRecords = _buildSales();

  List<SalesRecord> _buildSales() {
    final result = <SalesRecord>[];
    final mrs = employees.where((e) => e.role == UserRole.mr).toList();

    for (final mr in mrs) {
      for (var monthsBack = 11; monthsBack >= 0; monthsBack--) {
        final month = DateTime(today.year, today.month - monthsBack, 1);
        final target = targets.firstWhere(
          (t) =>
              t.employeeId == mr.id &&
              t.month.year == month.year &&
              t.month.month == month.month,
        );

        final amount = target.achievedAmount;
        result.add(
          SalesRecord(
            month: month,
            employeeId: mr.id,
            amount: amount,
            primaryAmount: amount * 0.58,
            secondaryAmount: amount * 0.42,
            unitsSold: (amount / 420).round(),
            productBreakup: [
              for (var i = 0; i < products.length; i++)
                ProductSales(
                  productId: products[i].id,
                  productName: products[i].name,
                  amount: amount * [0.29, 0.24, 0.19, 0.16, 0.12][i],
                  units: ((amount * [0.29, 0.24, 0.19, 0.16, 0.12][i]) /
                          products[i].mrp)
                      .round(),
                  sharePercent: [29, 24, 19, 16, 12][i].toDouble(),
                ),
            ],
          ),
        );
      }
    }
    return result;
  }

  // ============================================================ engagement ==

  late final List<FieldTask> tasks = _buildTasks();

  List<FieldTask> _buildTasks() {
    const titles = [
      'Complete RCPA for the cardiology range',
      'Collect outstanding payment from Wellness Forever',
      'Submit last month’s expense claims',
      'Onboard two new chemists in Chakala',
      'Schedule a CME with Dr. Anjali Sharma',
      'Update client contact details for Bandra cluster',
      'Push Glucomet XR with the top ten diabetologists',
      'Prepare the Lilavati formulary submission',
      'Verify stockist inventory before month close',
      'Re-detail Ostecal K2 to orthopaedic accounts',
      'Close the pending Fortis short-supply complaint',
      'Refresh e-detailing content on your tablet',
    ];

    final result = <FieldTask>[];
    final manager = employees.firstWhere((e) => e.id == 'emp-10');
    final mrs = fieldForce;
    var n = 0;

    for (final mr in mrs) {
      for (var i = 0; i < 5; i++) {
        n++;
        // Spread due dates either side of today so every task filter —
        // Open, Overdue and Completed — has rows to show.
        final due = today.add(Duration(days: -6 + i * 4 + n % 3));
        final status = switch (i) {
          0 => TaskStatus.completed,
          1 => TaskStatus.inProgress,
          2 => TaskStatus.assigned,
          3 => TaskStatus.assigned,
          _ => TaskStatus.completed,
        };

        result.add(
          FieldTask(
            id: 'tsk-$n',
            title: titles[n % titles.length],
            assignedToId: mr.id,
            assignedToName: mr.name,
            assignedById: manager.id,
            assignedByName: manager.name,
            dueDate: due,
            priority: TaskPriority.values[n % TaskPriority.values.length],
            status: status,
            instructions: 'Please update the status once complete so it '
                'reflects in this month’s review.',
            locationName: mr.areaName,
            createdAt: due.subtract(const Duration(days: 6)),
            completedAt: status == TaskStatus.completed
                ? due.subtract(const Duration(days: 1))
                : null,
          ),
        );
      }
    }
    return result;
  }

  late final List<AppNotification> notifications = [
    AppNotification(
      id: 'n-1',
      kind: NotificationKind.approvalCompleted,
      title: 'Travel plan approved',
      body: 'Your tour plan for ${_fmtShort(today.add(const Duration(days: 3)))} '
          'was approved by Ramesh Iyer.',
      createdAt: today.add(const Duration(hours: 10, minutes: 30)),
      deepLink: '/travel',
    ),
    AppNotification(
      id: 'n-2',
      kind: NotificationKind.approvalCompleted,
      title: 'Expense claim approved',
      body: '₹1,250 lodging claim approved for reimbursement.',
      createdAt: today.add(const Duration(hours: 9, minutes: 15)),
      deepLink: '/expenses',
    ),
    AppNotification(
      id: 'n-3',
      kind: NotificationKind.taskAssigned,
      title: 'New task assigned',
      body: 'Complete RCPA for the cardiology range by Friday.',
      createdAt: today.subtract(const Duration(hours: 20)),
      deepLink: '/tasks',
    ),
    AppNotification(
      id: 'n-4',
      kind: NotificationKind.visitReminder,
      title: 'Visit starting soon',
      body: 'Dr. Anjali Sharma at Apollo Clinic in 15 minutes.',
      createdAt: today.add(const Duration(hours: 10, minutes: 15)),
      isRead: true,
      deepLink: '/activity',
    ),
    AppNotification(
      id: 'n-5',
      kind: NotificationKind.targetUpdate,
      title: 'Monthly target updated',
      body: 'Your target for this month is now ₹6,25,000.',
      createdAt: today.subtract(const Duration(days: 2)),
      isRead: true,
      deepLink: '/business/targets',
    ),
    AppNotification(
      id: 'n-6',
      kind: NotificationKind.message,
      title: 'Ramesh Iyer',
      body: 'Please submit today’s report before 7 PM.',
      createdAt: today.subtract(const Duration(days: 1, hours: 4)),
      isRead: true,
      deepLink: '/chat',
    ),
    AppNotification(
      id: 'n-7',
      kind: NotificationKind.approvalRequested,
      title: 'Order awaiting approval',
      body: 'ORD-1001 for Apollo Clinic is pending your manager’s decision.',
      createdAt: today.add(const Duration(hours: 8, minutes: 40)),
      deepLink: '/business/orders',
    ),
    AppNotification(
      id: 'n-8',
      kind: NotificationKind.approvalCompleted,
      title: 'Leave approved',
      body: 'Your casual leave request has been approved.',
      createdAt: today.subtract(const Duration(days: 3, hours: 2)),
      isRead: true,
      deepLink: '/hr/leaves',
    ),
    AppNotification(
      id: 'n-9',
      kind: NotificationKind.visitReminder,
      title: 'Follow-up due',
      body: 'Dr. Mohan Singh was due for a follow-up visit this week.',
      createdAt: today.subtract(const Duration(days: 1, hours: 20)),
      deepLink: '/activity',
    ),
    AppNotification(
      id: 'n-10',
      kind: NotificationKind.message,
      title: 'Team Mumbai South',
      body: 'Tour plan updated for next week.',
      createdAt: today.subtract(const Duration(days: 1, hours: 3)),
      isRead: true,
      deepLink: '/chat',
    ),
    AppNotification(
      id: 'n-11',
      kind: NotificationKind.approvalCompleted,
      title: 'Expense rejected',
      body: 'Receipt is not legible. Please re-upload a clear photograph.',
      createdAt: today.subtract(const Duration(days: 5)),
      isRead: true,
      deepLink: '/expenses',
    ),
    AppNotification(
      id: 'n-12',
      kind: NotificationKind.taskAssigned,
      title: 'Task due tomorrow',
      body: 'Collect outstanding payment from Wellness Forever.',
      createdAt: today.subtract(const Duration(days: 2, hours: 6)),
      deepLink: '/tasks',
    ),
  ];

  late final List<ChatThread> chatThreads = [
    ChatThread(
      id: 'ch-1',
      title: 'Ramesh Iyer',
      subtitle: 'Area Sales Manager',
      lastMessage: 'Please submit today’s report before 7 PM.',
      lastMessageAt: today.add(const Duration(hours: 10, minutes: 30)),
      isPinned: true,
      unreadCount: 3,
      isOnline: true,
      participantIds: const ['emp-10'],
    ),
    ChatThread(
      id: 'ch-2',
      title: 'Team Mumbai South',
      subtitle: '6 members',
      lastMessage: 'Tour plan updated for next week.',
      lastMessageAt: today.subtract(const Duration(days: 1, hours: 3)),
      isGroup: true,
      isPinned: true,
      participantIds: const ['emp-1', 'emp-2', 'emp-3', 'emp-10'],
    ),
    ChatThread(
      id: 'ch-3',
      title: 'Marketing Team',
      subtitle: '14 members',
      lastMessage: 'New brochure shared for Cardiovex.',
      lastMessageAt: today.subtract(const Duration(days: 2)),
      isGroup: true,
      participantIds: const ['emp-10', 'emp-20'],
    ),
    ChatThread(
      id: 'ch-4',
      title: 'Sneha Patil',
      subtitle: 'Medical Representative',
      lastMessage: 'Can you cover Dadar tomorrow?',
      lastMessageAt: today.subtract(const Duration(days: 3)),
      participantIds: const ['emp-2'],
    ),
  ];

  late final Map<String, List<ChatMessage>> chatMessages = {
    'ch-1': [
      ChatMessage(
        id: 'm-1',
        threadId: 'ch-1',
        senderId: 'emp-10',
        senderName: 'Ramesh Iyer',
        text: 'Good morning Rahul. How is the Andheri coverage looking?',
        sentAt: today.add(const Duration(hours: 9, minutes: 12)),
      ),
      ChatMessage(
        id: 'm-2',
        threadId: 'ch-1',
        senderId: 'emp-1',
        senderName: 'Rahul Kumar',
        text: 'Morning sir. Three visits done, Dr. Sharma is next at 10:30.',
        sentAt: today.add(const Duration(hours: 9, minutes: 20)),
        isMine: true,
      ),
      ChatMessage(
        id: 'm-3',
        threadId: 'ch-1',
        senderId: 'emp-10',
        senderName: 'Ramesh Iyer',
        text: 'Good. Please carry the new Cardiovex visual aid.',
        sentAt: today.add(const Duration(hours: 9, minutes: 22)),
      ),
      ChatMessage(
        id: 'm-4',
        threadId: 'ch-1',
        senderId: 'emp-10',
        senderName: 'Ramesh Iyer',
        text: 'Please submit today’s report before 7 PM.',
        sentAt: today.add(const Duration(hours: 10, minutes: 30)),
      ),
    ],
    // Every thread carries history. A conversation that opens empty reads as a
    // broken feature rather than a quiet one.
    'ch-2': [
      ChatMessage(
        id: 'm-10',
        threadId: 'ch-2',
        senderId: 'emp-10',
        senderName: 'Ramesh Iyer',
        text: 'Team, the revised tour plans for next week are open for '
            'submission. Please file them by Thursday evening.',
        sentAt: today.subtract(const Duration(days: 2, hours: 6)),
      ),
      ChatMessage(
        id: 'm-11',
        threadId: 'ch-2',
        senderId: 'emp-2',
        senderName: 'Sneha Patil',
        text: 'Noted sir. Bandra cluster is done, Dadar by tomorrow.',
        sentAt: today.subtract(const Duration(days: 2, hours: 5)),
      ),
      ChatMessage(
        id: 'm-12',
        threadId: 'ch-2',
        senderId: 'emp-1',
        senderName: 'Rahul Kumar',
        text: 'Andheri East submitted. Two CME requests pending approval.',
        sentAt: today.subtract(const Duration(days: 2, hours: 4)),
        isMine: true,
      ),
      ChatMessage(
        id: 'm-13',
        threadId: 'ch-2',
        senderId: 'emp-3',
        senderName: 'Imran Shaikh',
        text: 'Kokilaben purchase committee meets Friday — I will need the '
            'updated rate card before that.',
        sentAt: today.subtract(const Duration(days: 1, hours: 8)),
      ),
      ChatMessage(
        id: 'm-14',
        threadId: 'ch-2',
        senderId: 'emp-10',
        senderName: 'Ramesh Iyer',
        text: 'Tour plan updated for next week. Rate card shared in '
            'Resources.',
        sentAt: today.subtract(const Duration(days: 1, hours: 3)),
      ),
    ],
    'ch-3': [
      ChatMessage(
        id: 'm-20',
        threadId: 'ch-3',
        senderId: 'emp-20',
        senderName: 'Kavita Rao',
        text: 'The Q3 campaign for the cardiology range goes live on Monday.',
        sentAt: today.subtract(const Duration(days: 4, hours: 5)),
      ),
      ChatMessage(
        id: 'm-21',
        threadId: 'ch-3',
        senderId: 'emp-10',
        senderName: 'Ramesh Iyer',
        text: 'Will the visual aid be printed or e-detailing only?',
        sentAt: today.subtract(const Duration(days: 4, hours: 4)),
      ),
      ChatMessage(
        id: 'm-22',
        threadId: 'ch-3',
        senderId: 'emp-20',
        senderName: 'Kavita Rao',
        text: 'E-detailing first. Printed leave-behinds reach HQ next week.',
        sentAt: today.subtract(const Duration(days: 3, hours: 9)),
      ),
      ChatMessage(
        id: 'm-23',
        threadId: 'ch-3',
        senderId: 'emp-20',
        senderName: 'Kavita Rao',
        text: 'New brochure shared for Cardiovex.',
        sentAt: today.subtract(const Duration(days: 2)),
      ),
    ],
    'ch-4': [
      ChatMessage(
        id: 'm-30',
        threadId: 'ch-4',
        senderId: 'emp-2',
        senderName: 'Sneha Patil',
        text: 'Rahul, Dr. Mehta rescheduled to Thursday. Are you covering '
            'Dadar that day?',
        sentAt: today.subtract(const Duration(days: 3, hours: 7)),
      ),
      ChatMessage(
        id: 'm-31',
        threadId: 'ch-4',
        senderId: 'emp-1',
        senderName: 'Rahul Kumar',
        text: 'I can swap my Andheri slot. Will confirm once the tour plan '
            'is approved.',
        sentAt: today.subtract(const Duration(days: 3, hours: 6)),
        isMine: true,
      ),
      ChatMessage(
        id: 'm-32',
        threadId: 'ch-4',
        senderId: 'emp-2',
        senderName: 'Sneha Patil',
        text: 'Can you cover Dadar tomorrow?',
        sentAt: today.subtract(const Duration(days: 3)),
      ),
    ],
  };

  late final List<Complaint> complaints = [
    Complaint(
      id: 'cmp-1',
      reference: 'CMP-2041',
      clientId: 'cli-h1',
      clientName: 'Apollo Clinic',
      subject: 'Damaged strips in the last consignment',
      description:
          'Four strips of Cardiovex 40 arrived with broken blister packing. '
          'Requesting replacement before the weekend.',
      status: ComplaintStatus.inReview,
      createdAt: today.subtract(const Duration(days: 4)),
      productId: 'p-1',
      productName: 'Cardiovex 40',
      mobile: '02224451100',
      email: 'purchase@apolloclinic.in',
    ),
    Complaint(
      id: 'cmp-2',
      reference: 'CMP-2038',
      clientId: 'cli-c1',
      clientName: 'Wellness Forever',
      subject: 'Invoice mismatch on order ORD-1004',
      description: 'Billed quantity does not match the delivered quantity.',
      status: ComplaintStatus.resolved,
      createdAt: today.subtract(const Duration(days: 18)),
      resolution: 'Credit note issued and shared with the store manager.',
    ),
    Complaint(
      id: 'cmp-3',
      reference: 'CMP-2049',
      clientId: 'cli-2',
      clientName: 'Dr. Mohan Singh',
      subject: 'Sample stock not received',
      description: 'Physician samples requested last month are still pending.',
      status: ComplaintStatus.open,
      createdAt: today.subtract(const Duration(days: 1)),
    ),
    Complaint(
      id: 'cmp-4',
      reference: 'CMP-2052',
      clientId: 'cli-h3',
      clientName: 'Fortis Healthcare',
      subject: 'Short supply against purchase order',
      description:
          'Ordered 40 units of Glucomet XR 1000, received 25. Balance not '
          'listed on the invoice.',
      status: ComplaintStatus.inReview,
      createdAt: today.subtract(const Duration(days: 6)),
      productId: 'p-7',
      productName: 'Glucomet XR 1000',
      mobile: '02224451114',
    ),
    Complaint(
      id: 'cmp-5',
      reference: 'CMP-2044',
      clientId: 'cli-c2',
      clientName: 'Apollo Pharmacy',
      subject: 'Near-expiry stock delivered',
      description:
          'Batch delivered has four months to expiry. Store cannot take it '
          'on the shelf.',
      status: ComplaintStatus.resolved,
      createdAt: today.subtract(const Duration(days: 24)),
      productId: 'p-2',
      productName: 'Neurokind Plus',
      resolution: 'Stock swapped with a fresh batch and collected on 12th.',
    ),
    Complaint(
      id: 'cmp-6',
      reference: 'CMP-2031',
      clientId: 'cli-5',
      clientName: 'Dr. Sanjay Gupta',
      subject: 'Packaging print error',
      description: 'Dosage text on the carton does not match the insert.',
      status: ComplaintStatus.closed,
      createdAt: today.subtract(const Duration(days: 46)),
      productId: 'p-10',
      productName: 'Pediacef 50 DS',
      resolution: 'Escalated to QA. Affected batch withdrawn from the region.',
    ),
    Complaint(
      id: 'cmp-7',
      reference: 'CMP-2055',
      clientId: 'cli-c3',
      clientName: 'MedPlus Andheri',
      subject: 'Credit note not received',
      description:
          'Return processed three weeks ago, credit note still pending from '
          'accounts.',
      status: ComplaintStatus.open,
      createdAt: today.subtract(const Duration(hours: 20)),
      mobile: '9930011402',
    ),
  ];

  /// Surveys span the whole team, not just the demo user, so a manager signing
  /// in sees a populated list rather than an empty one.
  late final List<SurveyResponse> surveys = [
    SurveyResponse(
      id: 'srv-1',
      employeeId: 'emp-1',
      clientId: 'cli-1',
      clientName: 'Dr. Anjali Sharma',
      clientType: ClientType.doctor,
      submittedAt: today.subtract(const Duration(days: 5)),
      feedback: 'Prefers evidence-based detailing with recent trial data.',
      remarks: 'Open to a CME session in the next quarter.',
      locationName: 'Apollo Clinic, Andheri East',
      rating: 4,
    ),
    SurveyResponse(
      id: 'srv-2',
      employeeId: 'emp-1',
      clientId: 'cli-c2',
      clientName: 'Apollo Pharmacy',
      clientType: ClientType.chemist,
      submittedAt: today.subtract(const Duration(days: 12)),
      feedback: 'Competitor offering better margins on the respiratory range.',
      locationName: 'Andheri East',
      rating: 3,
    ),
    SurveyResponse(
      id: 'srv-3',
      employeeId: 'emp-1',
      clientId: 'cli-h1',
      clientName: 'Apollo Clinic',
      clientType: ClientType.hospital,
      submittedAt: today.subtract(const Duration(days: 19)),
      feedback:
          'Purchase committee wants a consolidated rate card across the '
          'cardiology and diabetology ranges before the next tender.',
      remarks: 'Decision expected at the Friday committee meeting.',
      locationName: 'Andheri East',
      rating: 4,
    ),
    SurveyResponse(
      id: 'srv-4',
      employeeId: 'emp-2',
      clientId: 'cli-3',
      clientName: 'Dr. Priya Nair',
      clientType: ClientType.doctor,
      submittedAt: today.subtract(const Duration(days: 3)),
      feedback:
          'Happy with Femiron XT tolerability. Asked for paediatric data on '
          'Pediacef before switching.',
      locationName: 'Bandra',
      rating: 5,
    ),
    SurveyResponse(
      id: 'srv-5',
      employeeId: 'emp-2',
      clientId: 'cli-c1',
      clientName: 'Wellness Forever',
      clientType: ClientType.chemist,
      submittedAt: today.subtract(const Duration(days: 9)),
      feedback: 'Stock movement steady, but delivery windows are inconsistent.',
      remarks: 'Requested a fixed weekly delivery slot.',
      locationName: 'Bandra',
      rating: 3,
    ),
    SurveyResponse(
      id: 'srv-6',
      employeeId: 'emp-3',
      clientId: 'cli-4',
      clientName: 'Dr. Rahul Mehta',
      clientType: ClientType.doctor,
      submittedAt: today.subtract(const Duration(days: 7)),
      feedback:
          'Prescribes competitor molecule out of habit. Open to a trial pack '
          'if supported with dosing literature.',
      locationName: 'Dadar',
      rating: 2,
    ),
    SurveyResponse(
      id: 'srv-7',
      employeeId: 'emp-3',
      clientId: 'cli-h2',
      clientName: 'Lilavati Hospital',
      clientType: ClientType.hospital,
      submittedAt: today.subtract(const Duration(days: 15)),
      feedback: 'Formulary review scheduled next month; submission required.',
      remarks: 'Needs stability data and a comparative pricing sheet.',
      locationName: 'Dadar',
      rating: 4,
    ),
    SurveyResponse(
      id: 'srv-8',
      employeeId: 'emp-4',
      clientId: 'cli-6',
      clientName: 'Dr. Meera Joshi',
      clientType: ClientType.doctor,
      submittedAt: today.subtract(const Duration(days: 2)),
      feedback:
          'Strong response to the Ostecal K2 evidence deck. Asked for sample '
          'strips for elderly patients.',
      locationName: 'Goregaon',
      rating: 5,
    ),
    SurveyResponse(
      id: 'srv-9',
      employeeId: 'emp-5',
      clientId: 'cli-8',
      clientName: 'Dr. Arvind Rao',
      clientType: ClientType.doctor,
      submittedAt: today.subtract(const Duration(days: 11)),
      feedback:
          'Limited time for detailing. Prefers a short e-detail on the tablet '
          'over printed material.',
      locationName: 'Borivali',
      rating: 3,
    ),
  ];

  static String _fmtShort(DateTime d) => '${d.day}/${d.month}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
