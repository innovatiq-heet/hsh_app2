class Routes {
  Routes._();

  static const splash = '/';
  static const login = '/login';
  static const register = '/register';

  static const studentHome = '/student';
  static const studentProfileEdit = '/student/profile/edit';
  static const attendanceHistory = '/student/attendance/history';
  static const leave = '/student/leave';
  static const leaveAdd = '/student/leave/add';
  static const fees = '/student/fees';
  static const feesPayNow = '/student/fees/pay';
  static const laundryTicketDetail = '/student/laundry/ticket';
  static const complaintAdd = '/student/complaint/add';
  static const complaintDetail = '/student/complaint/detail';
  static const notes = '/student/notes';
  static const chat = '/student/chat';
  static const services = '/student/services';
  static const setting = '/student/setting';
  static const vehicle = '/student/vehicle';

  static const laundryModule = '/laundry_module';

  static const complainSolverModule = '/complain_module';
  static const complainAdminDetail = '/complain_module/detail';

  static const operatorShell = '/operator';
  static const operatorDirectory = '/operator/directory';
  static const operatorAdmissions = '/operator/admissions';
  static const operatorRoomSwap = '/operator/room-swap';
  static const operatorMarkLeft = '/operator/mark-left';
  static const operatorLeaveApprovals = '/operator/leave-approvals';
  static const operatorFeeApprovals = '/operator/fee-approvals';
  static const operatorDepositDebit = '/operator/deposit-debit';
  static const operatorSabha = '/operator/sabha';
  static const operatorAttendanceOnBehalf = '/operator/attendance-on-behalf';
}
