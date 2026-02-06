// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Vlinix Dashboard';

  @override
  String get menuOverview => 'Overview';

  @override
  String get menuAgenda => 'Schedule';

  @override
  String get menuClients => 'Clients';

  @override
  String get menuVehicles => 'Vehicles';

  @override
  String get menuServices => 'Services';

  @override
  String get menuFinance => 'Finance';

  @override
  String get menuLogout => 'Logout';

  @override
  String get dashboardClients => 'Clients';

  @override
  String get dashboardVehicles => 'Fleet';

  @override
  String get dashboardToday => 'Today';

  @override
  String get agendaToday => 'Today\'s Schedule';

  @override
  String get agendaUpcoming => 'Upcoming Appointments';

  @override
  String get agendaEmptyToday => 'All clear for today!';

  @override
  String get agendaEmptyUpcoming => 'No upcoming appointments.';

  @override
  String get btnNew => 'New';

  @override
  String get btnSave => 'Save';

  @override
  String get btnSchedule => 'Schedule';

  @override
  String get btnUpdate => 'Save Changes';

  @override
  String get btnCancel => 'Cancel';

  @override
  String get btnDelete => 'Delete';

  @override
  String get btnEdit => 'Edit';

  @override
  String get labelClient => 'Client';

  @override
  String get labelVehicle => 'Vehicle';

  @override
  String get labelService => 'Service';

  @override
  String get labelName => 'Full Name';

  @override
  String get labelPhone => 'Phone';

  @override
  String get labelEmail => 'Email';

  @override
  String get labelModel => 'Model';

  @override
  String get labelPlate => 'Plate';

  @override
  String get labelColor => 'Color';

  @override
  String get labelOwner => 'Owner';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusDone => 'Done';

  @override
  String get dialogPaymentTitle => 'Payment Method';

  @override
  String get paymentCash => 'Cash';

  @override
  String get paymentCard => 'Card';

  @override
  String get paymentPlan => 'Monthly Plan';

  @override
  String get filterAll => 'All';

  @override
  String get financeTitle => 'Financial Control';

  @override
  String get financeTotal => 'Total Revenue';

  @override
  String get financeEmpty => 'No services completed this month.';

  @override
  String get titleManageClients => 'Manage Clients';

  @override
  String get titleAllVehicles => 'All Vehicles';

  @override
  String get msgNoClients => 'No clients found.';

  @override
  String get msgNoVehicles => 'No vehicles found.';

  @override
  String get msgClientCreated => 'Client created!';

  @override
  String get msgClientUpdated => 'Client updated!';

  @override
  String get msgClientDeleted => 'Client deleted!';

  @override
  String get msgGoogleUpdated => 'Google Calendar Updated!';

  @override
  String get msgGoogleDeleted => 'Removed from Google Calendar!';

  @override
  String get msgErrorDeleteClient =>
      'Error: Cannot delete client with appointments!';

  @override
  String get msgErrorDeleteVehicle => 'Error: Car has appointments!';

  @override
  String get titleNewClient => 'New Client';

  @override
  String get titleEditClient => 'Edit Client';

  @override
  String get titleEditVehicle => 'Edit Vehicle';

  @override
  String get dialogDeleteTitle => 'Delete?';

  @override
  String get dialogDeleteContent => 'This will delete the record permanently.';

  @override
  String get labelSelectServices => 'Select Services';

  @override
  String get labelTotal => 'Estimated Total';

  @override
  String get msgSelectService => 'Select at least one service!';

  @override
  String get msgSelectClientVehicle => 'Select Client and Vehicle!';

  @override
  String get tooltipEditProfile => 'Edit Profile';

  @override
  String get titleNewVehicle => 'New Vehicle';

  @override
  String get titleNewAppointment => 'New Appointment';

  @override
  String get labelProfileInfo => 'Your Information';

  @override
  String get msgTapPhoto => 'Tap photo to change';

  @override
  String get labelDisplayName => 'Display Name';

  @override
  String get hintSearchClient => 'Search Client';

  @override
  String get hintSearchVehicle => 'Search Vehicle';

  @override
  String get hintSearchGeneric => 'Name, phone or email...';
}
