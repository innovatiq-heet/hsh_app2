import 'package:flutter_test/flutter_test.dart';
import 'package:hsh_app2/core/enums/user_role.dart';
import 'package:hsh_app2/core/models/birthday/birthday_models.dart';
import 'package:hsh_app2/core/network/responses/authentication/auth_session_response.dart';
import 'package:hsh_app2/features/birthday/controllers/admin_birthday_controller.dart';

void main() {
  group('Birthday Models & Serialization', () {
    test('BirthdayConfigModel parses JSON correctly', () {
      final json = {
        'id': 1,
        'isEnabled': true,
        'sendTime': '08:30',
        'targetAudience': 'student_only',
        'preferWhatsAppNumber': true,
        'adminNotificationPhone': '9876543210',
        'messageTemplate': 'Happy Birthday {first_name}!',
        'imageUrl': 'https://example.com/card.jpg',
        'lastRunDate': '2026-10-15',
      };

      final config = BirthdayConfigModel.fromJson(json);
      expect(config.id, 1);
      expect(config.isEnabled, true);
      expect(config.sendTime, '08:30');
      expect(config.targetAudience, 'student_only');
      expect(config.adminNotificationPhone, '9876543210');
      expect(config.messageTemplate, 'Happy Birthday {first_name}!');
    });

    test('BirthdayStudentModel handles Room N/A properly', () {
      final json = {
        'studentId': 178038,
        'name': 'AADHYA VIJAYKUMAR DAVE',
        'studentCode': '0873',
        'phone': '9824803024',
        'whatsappNumber': '9824803024',
        'room': 'N/A',
        'dob': '2005-05-06',
        'isActive': false,
      };

      final student = BirthdayStudentModel.fromJson(json);
      expect(student.studentId, 178038);
      expect(student.name, 'AADHYA VIJAYKUMAR DAVE');
      expect(student.room, 'N/A');
      expect(student.dob, '2005-05-06');
      expect(student.isActive, false);
    });

    test('BirthdayDashboardData parses full payload', () {
      final json = {
        'config': {'id': 1, 'isEnabled': true, 'sendTime': '08:00'},
        'todaysBirthdays': [
          {
            'studentId': 101,
            'name': 'Krutarth Patel',
            'studentCode': 'HSH-102',
            'room': '204',
          },
        ],
        'tomorrowsBirthdays': [
          {
            'studentId': 105,
            'name': 'Rahul Sharma',
            'studentCode': 'HSH-105',
            'room': '306',
          },
        ],
        'recentLogs': [],
        'isWhatsAppConnected': true,
        'senderPhone': '919999999999',
      };

      final dashboard = BirthdayDashboardData.fromJson(json);
      expect(dashboard.isWhatsAppConnected, true);
      expect(dashboard.todaysBirthdays.length, 1);
      expect(dashboard.tomorrowsBirthdays.length, 1);
      expect(dashboard.todaysBirthdays.first.name, 'Krutarth Patel');
      expect(dashboard.tomorrowsBirthdays.first.name, 'Rahul Sharma');
    });

    test('BirthdayDashboardData parses isLeader and leaderGroup correctly', () {
      final json = {
        'config': {'id': 1},
        'todaysBirthdays': [],
        'tomorrowsBirthdays': [],
        'recentLogs': [],
        'isWhatsAppConnected': true,
        'isLeader': true,
        'leaderGroup': 'Param',
        'leaderTemplate': 'Happy Birthday {first_name} bhai! From your leader.',
      };

      final data = BirthdayDashboardData.fromJson(json);
      expect(data.isLeader, true);
      expect(data.leaderGroup, 'Param');
      expect(data.leaderTemplate, 'Happy Birthday {first_name} bhai! From your leader.');
    });

    test('BirthdayConfigModel preserves targetAudience options', () {
      const studentOnly = BirthdayConfigModel(targetAudience: 'student_only');
      const parentOnly = BirthdayConfigModel(targetAudience: 'parent_only');
      const studentAndParent = BirthdayConfigModel(targetAudience: 'student_and_parent');

      expect(studentOnly.targetAudience, 'student_only');
      expect(parentOnly.targetAudience, 'parent_only');
      expect(studentAndParent.targetAudience, 'student_and_parent');

      expect(parentOnly.toJson()['targetAudience'], 'parent_only');
      expect(studentAndParent.toJson()['targetAudience'], 'student_and_parent');
    });

    test('UserRole and AuthSessionResponse recognize leader roles properly', () {
      expect(UserRoleX.fromApi('leader'), UserRole.leader);
      expect(UserRoleX.fromApi('wing-leader'), UserRole.leader);
      expect(UserRoleX.fromApi('floor-leader'), UserRole.leader);

      final sessionFromRoles = AuthSessionResponse.fromJson({
        'id': 123,
        'name': 'Leader Student',
        'role': 'student',
        'roles': ['student', 'leader'],
      });
      expect(sessionFromRoles.role, UserRole.leader);

      final sessionFromFlag = AuthSessionResponse.fromJson({
        'id': 124,
        'name': 'Leader Student 2',
        'role': 'STUDENT',
        'is_leader': true,
      });
      expect(sessionFromFlag.role, UserRole.leader);
    });

    test('AdminBirthdayController.fillTemplate replaces all dynamic placeholders', () {
      const template = 'Hare Krishna {first_name}! {student_name} from room {room_number} (code: {student_code})';
      final formatted = AdminBirthdayController.fillTemplate(
        template,
        firstName: 'Smit',
        fullName: 'Smit Hasmukhbhai Padaliya',
        room: '308',
        code: '0028',
      );
      expect(
        formatted,
        'Hare Krishna Smit! Smit Hasmukhbhai Padaliya from room 308 (code: 0028)',
      );
    });
  });
}
