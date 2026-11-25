import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vlinix/main.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'package:vlinix/widgets/user_profile_menu.dart';
// import 'package:vlinix/services/google_calendar_service.dart'; // <--- COMENTADO

import 'add_client_screen.dart';
import 'add_vehicle_screen.dart';
import 'add_appointment_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _todayAppointmentsCount = 0;
  List<Map<String, dynamic>> _todayAppointments = [];
  List<Map<String, dynamic>> _upcomingAppointments = [];
  bool _isLoading = true;

  String _announcementMessage = '';
  bool _isAnnouncementActive = false;
  RealtimeChannel? _announcementChannel;
  bool _userClosedAnnouncement = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    _setupAnnouncementListener();
  }

  @override
  void dispose() {
    if (_announcementChannel != null) {
      AppBackend.client.removeChannel(_announcementChannel!);
    }
    super.dispose();
  }

  Future<void> _setupAnnouncementListener() async {
    if (AppBackend.isDemo) return;
    final supabase = AppBackend.client;

    try {
      final data = await supabase
          .from('global_announcements')
          .select()
          .eq('id', 1)
          .maybeSingle();

      if (data != null && mounted) {
        setState(() {
          _announcementMessage = data['message'] ?? '';
          _isAnnouncementActive = data['is_active'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao ler aviso: $e');
    }

    _announcementChannel = supabase
        .channel('public:global_announcements')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'global_announcements',
          callback: (payload) {
            if (mounted) {
              setState(() {
                _userClosedAnnouncement = false;
                if (payload.eventType == PostgresChangeEvent.update ||
                    payload.eventType == PostgresChangeEvent.insert) {
                  _announcementMessage = payload.newRecord['message'] ?? '';
                  _isAnnouncementActive =
                      payload.newRecord['is_active'] ?? false;
                }
              });
            }
          },
        )
        .subscribe();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final supabase = AppBackend.client;

    try {
      final now = DateTime.now();
      final startOfDay = DateTime(
        now.year,
        now.month,
        now.day,
      ).toUtc().toIso8601String();
      final endOfDay = DateTime(
        now.year,
        now.month,
        now.day,
        23,
        59,
        59,
      ).toUtc().toIso8601String();

      const selectQuery = '''
        *,
        clients(full_name, address), 
        vehicles(model, category), 
        services(name),
        appointment_services(id, price, completed, service_id, services(name))
      ''';

      final todayData = await supabase
          .from('appointments')
          .select(selectQuery)
          .gte('start_time', startOfDay)
          .lte('start_time', endOfDay)
          .order('start_time', ascending: true);

      final upcomingData = await supabase
          .from('appointments')
          .select(selectQuery)
          .gt('start_time', endOfDay)
          .order('start_time', ascending: true);

      if (mounted) {
        setState(() {
          _todayAppointments = List<Map<String, dynamic>>.from(todayData);
          _todayAppointmentsCount = _todayAppointments.length;
          _upcomingAppointments = List<Map<String, dynamic>>.from(upcomingData);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro Dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openMap(String address) async {
    if (AppBackend.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Endereço fictício. Mapas externos estão desativados na demonstração.',
          ),
        ),
      );
      return;
    }
    final lang = AppLocalizations.of(context)!;
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorOpenMap),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _openShop() async {
    if (AppBackend.isDemo) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A loja externa não faz parte da demonstração local.'),
        ),
      );
      return;
    }
    final lang = AppLocalizations.of(context)!;
    final Uri url = Uri.parse('https://vlinix.com/');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorGeneric('Could not open shop.')),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _updateStatus(
    int id,
    String newStatus, {
    String? paymentMethod,
    double? tipAmount,
  }) async {
    final supabase = AppBackend.client;
    String feedbackMsg = '';
    final lang = AppLocalizations.of(context)!;

    try {
      final currentData = await supabase
          .from('appointments')
          .select(
            '*, clients(full_name), appointment_services(price, services(name))',
          )
          .eq('id', id)
          .single();

      final String? currentGoogleId = currentData['google_event_id'];
      String? newGoogleEventId;

      /* --- LÓGICA DO GOOGLE CALENDAR COMENTADA ---
      if (newStatus == 'cancelado' || newStatus == 'concluido') {
        if (currentGoogleId != null && currentGoogleId.isNotEmpty) {
          await GoogleCalendarService.instance.deleteEvent(currentGoogleId);
        }
      } else if (newStatus == 'pendente') {
        final clientName = currentData['clients']['full_name'];
        final startTime = DateTime.parse(currentData['start_time']);
        final endTime = startTime.add(const Duration(hours: 1));

        final items = currentData['appointment_services'] as List;
        final servicesNames = items
            .map((i) => i['services']['name'])
            .join(', ');
        final totalPrice = items.fold(0.0, (sum, i) => sum + (i['price'] ?? 0));

        final title = 'Vlinix: $servicesNames - $clientName';
        final currency = NumberFormat.simpleCurrency(name: '').currencySymbol;

        final desc = lang.msgGoogleReactivated(
          servicesNames,
          '$currency $totalPrice',
        );
        
        newGoogleEventId = await GoogleCalendarService.instance.insertEvent(
          title: title,
          description: desc,
          startTime: startTime,
          endTime: endTime,
        );
      }
      --------------------------------------------------- */

      final Map<String, dynamic> updateData = {'status': newStatus};

      if (newStatus == 'concluido') {
        updateData['payment_method'] = paymentMethod;
        if (tipAmount != null) {
          updateData['tip_amount'] = tipAmount;
        }
      } else {
        updateData['payment_method'] = null;
        updateData['tip_amount'] = 0.0;
      }

      if (newGoogleEventId != null) {
        updateData['google_event_id'] = newGoogleEventId;
      } else if (newStatus == 'cancelado' || newStatus == 'concluido') {
        updateData['google_event_id'] = null;
      }

      await supabase.from('appointments').update(updateData).eq('id', id);
      await _loadDashboardData();

      if (mounted) {
        String msg = '';
        Color color = Colors.blue;

        if ((newStatus == 'cancelado' || newStatus == 'concluido') &&
            currentGoogleId != null &&
            currentGoogleId.isNotEmpty) {
          feedbackMsg = lang.msgRemovedFromGoogle;
        } else if (newStatus == 'pendente' && newGoogleEventId != null) {
          feedbackMsg = lang.msgAddedToGoogle;
        }

        if (newStatus == 'concluido') {
          msg = '${lang.statusDone} ✅';
          color = AppColors.success;
        } else if (newStatus == 'em_andamento') {
          msg = '${lang.statusInProgress} 🚀';
          color = Colors.blue;
        } else if (newStatus == 'cancelado') {
          msg = '${lang.msgAppointmentCancelled} 🚫';
          color = Colors.grey;
        } else {
          msg = '${lang.statusPending} 🟠';
          color = Colors.orange;
        }

        ScaffoldMessenger.of(context).hideCurrentSnackBar();

        if (feedbackMsg.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$msg\n$feedbackMsg'),
              backgroundColor: color,
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.msgErrorGeneric(e.toString()),
            ),
            backgroundColor: AppColors.error,
          ),
        );
    }
  }

  Future<void> _toggleServiceCompletion(
    int appointmentServiceId,
    bool currentStatus,
  ) async {
    try {
      await AppBackend.client
          .from('appointment_services')
          .update({'completed': !currentStatus})
          .eq('id', appointmentServiceId);
      await _loadDashboardData();
    } catch (e) {
      debugPrint('Erro ao atualizar serviço: $e');
    }
  }

  void _showChecklistDialog(Map<String, dynamic> apt) {
    final lang = AppLocalizations.of(context)!;
    final currencySymbol = NumberFormat.simpleCurrency(name: '').currencySymbol;
    final List items = apt['appointment_services'] ?? [];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            bool allCompleted = items.every((i) => i['completed'] == true);
            return AlertDialog(
              title: Text(lang.titleChecklist),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final bool isChecked = item['completed'] ?? false;
                    return CheckboxListTile(
                      title: Text(item['services']['name']),
                      subtitle: Text("$currencySymbol ${item['price']}"),
                      value: isChecked,
                      activeColor: AppColors.success,
                      onChanged: (val) async {
                        await _toggleServiceCompletion(item['id'], isChecked);
                        setStateDialog(() {
                          item['completed'] = val;
                        });
                        _loadDashboardData();
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    lang.btnCancel,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: allCompleted
                        ? AppColors.success
                        : Colors.grey,
                  ),
                  onPressed: allCompleted
                      ? () {
                          Navigator.pop(ctx);
                          _showPaymentDialog(apt['id']);
                        }
                      : () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(lang.msgCompleteAllServices),
                            ),
                          );
                        },
                  child: Text(lang.btnGoToPayment),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPaymentDialog(int appointmentId) {
    final lang = AppLocalizations.of(context)!;
    final currencySymbol = lang.localeName == 'pt' ? 'R\$' : '\$';
    final TextEditingController tipController = TextEditingController();
    bool hasTip = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(lang.dialogPaymentTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      lang.dialogPaymentTip,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    value: hasTip,
                    activeColor: AppColors.accent,
                    onChanged: (val) {
                      setStateDialog(() {
                        hasTip = val ?? false;
                        if (!hasTip) tipController.clear();
                      });
                    },
                  ),
                  if (hasTip)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: TextField(
                        controller: tipController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '${lang.labelTip} ($currencySymbol)',
                          prefixIcon: const Icon(Icons.attach_money),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildPaymentOption(
                    ctx,
                    appointmentId,
                    lang.paymentCash,
                    'dinheiro',
                    Icons.money,
                    Colors.green,
                    tipController,
                  ),
                  _buildPaymentOption(
                    ctx,
                    appointmentId,
                    lang.paymentCard,
                    'cartao',
                    Icons.credit_card,
                    Colors.blue,
                    tipController,
                  ),
                  _buildPaymentOption(
                    ctx,
                    appointmentId,
                    lang.paymentPlan,
                    'plano',
                    Icons.calendar_today,
                    Colors.purple,
                    tipController,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    lang.btnCancel,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentOption(
    BuildContext ctx,
    int id,
    String label,
    String internalValue,
    IconData icon,
    Color color,
    TextEditingController tipController,
  ) {
    return InkWell(
      onTap: () {
        double tipAmount = 0.0;
        if (tipController.text.isNotEmpty) {
          tipAmount =
              double.tryParse(tipController.text.replaceAll(',', '.')) ?? 0.0;
        }
        Navigator.pop(ctx);
        _updateStatus(
          id,
          'concluido',
          paymentMethod: internalValue,
          tipAmount: tipAmount,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(fontSize: 16)),
          ],
        ),
      ),
    );
  }

  // --- NOVA FUNÇÃO DA FASE 3: EDITAR AGENDAMENTO CONCLUÍDO ---
  void _showEditCompletedDialog(Map<String, dynamic> apt) async {
    final lang = AppLocalizations.of(context)!;
    final supabase = AppBackend.client;
    final currencySymbol = NumberFormat.simpleCurrency(name: '').currencySymbol;

    final allServicesRes = await supabase
        .from('services')
        .select()
        .order('name');
    final List<Map<String, dynamic>> allAvailableServices =
        List<Map<String, dynamic>>.from(allServicesRes);

    final TextEditingController tipController = TextEditingController(
      text: apt['tip_amount'] != null && apt['tip_amount'] > 0
          ? apt['tip_amount'].toString()
          : '',
    );

    String currentPaymentMethod = apt['payment_method'] ?? 'dinheiro';
    List currentServices = List.from(apt['appointment_services'] ?? []);

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            double totalServices = currentServices.fold(
              0.0,
              (sum, i) => sum + (i['price'] ?? 0),
            );
            double tip =
                double.tryParse(tipController.text.replaceAll(',', '.')) ?? 0.0;
            double grandTotal = totalServices + tip;

            return AlertDialog(
              title: Text(
                lang.titleEditCompletedService, // <-- TRADUZIDO AQUI
                style: const TextStyle(color: AppColors.primary),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lang.labelServicesRendered, // <-- TRADUZIDO AQUI
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ...allAvailableServices.map((service) {
                        bool isSelected = currentServices.any(
                          (s) => s['service_id'] == service['id'],
                        );
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(service['name']),
                          subtitle: Text("$currencySymbol ${service['price']}"),
                          value: isSelected,
                          activeColor: AppColors.success,
                          onChanged: (bool? value) {
                            setStateDialog(() {
                              if (value == true) {
                                currentServices.add({
                                  'service_id': service['id'],
                                  'price': service['price'],
                                  'completed': true,
                                  'services': {'name': service['name']},
                                });
                              } else {
                                currentServices.removeWhere(
                                  (s) => s['service_id'] == service['id'],
                                );
                              }
                            });
                          },
                        );
                      }),
                      const Divider(height: 32),
                      Text(
                        lang.dialogPaymentTitle, // Reaproveitado
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<String>(
                        value: currentPaymentMethod,
                        isExpanded: true,
                        items: [
                          DropdownMenuItem(
                            value: 'dinheiro',
                            child: Text(lang.paymentCash), // <-- TRADUZIDO AQUI
                          ),
                          DropdownMenuItem(
                            value: 'cartao',
                            child: Text(lang.paymentCard), // <-- TRADUZIDO AQUI
                          ),
                          DropdownMenuItem(
                            value: 'plano',
                            child: Text(lang.paymentPlan), // <-- TRADUZIDO AQUI
                          ),
                        ],
                        onChanged: (val) {
                          setStateDialog(() {
                            currentPaymentMethod = val!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      Text(
                        lang.labelTip, // Reaproveitado
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: tipController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (val) => setStateDialog(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.attach_money),
                          hintText: '0.00',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              lang.labelNewTotal, // <-- TRADUZIDO AQUI
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '$currencySymbol ${grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    lang.btnCancel,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () async {
                    await supabase
                        .from('appointment_services')
                        .delete()
                        .eq('appointment_id', apt['id']);

                    if (currentServices.isNotEmpty) {
                      final userId = supabase.auth.currentUser!.id;
                      final List<Map<String, dynamic>> servicesToInsert =
                          currentServices
                              .map(
                                (s) => {
                                  'user_id': userId,
                                  'appointment_id': apt['id'],
                                  'service_id': s['service_id'],
                                  'price': s['price'],
                                  'completed': true,
                                },
                              )
                              .toList();
                      await supabase
                          .from('appointment_services')
                          .insert(servicesToInsert);
                    }

                    double finalTip =
                        double.tryParse(
                          tipController.text.replaceAll(',', '.'),
                        ) ??
                        0.0;
                    await supabase
                        .from('appointments')
                        .update({
                          'payment_method': currentPaymentMethod,
                          'tip_amount': finalTip,
                        })
                        .eq('id', apt['id']);

                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            lang.msgPaymentServicesUpdated,
                          ), // <-- TRADUZIDO AQUI
                          backgroundColor: AppColors.success,
                        ),
                      );
                      _loadDashboardData();
                    }
                  },
                  child: Text(lang.btnSave), // Reaproveitado
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(String isoString) {
    return DateFormat('HH:mm').format(DateTime.parse(isoString).toLocal());
  }

  Map<String, dynamic> _processAppointmentData(Map<String, dynamic> apt) {
    final lang = AppLocalizations.of(context)!;
    String serviceNames = '';
    double totalPrice = 0.0;

    if (apt['appointment_services'] != null &&
        (apt['appointment_services'] as List).isNotEmpty) {
      final items = apt['appointment_services'] as List;
      serviceNames = items.map((i) => i['services']['name']).join(', ');
      totalPrice = items.fold(0.0, (sum, i) => sum + (i['price'] ?? 0.0));
    } else if (apt['services'] != null) {
      serviceNames = apt['services']['name'];
    }

    double tip = apt['tip_amount'] != null
        ? double.parse(apt['tip_amount'].toString())
        : 0.0;
    double grandTotal = totalPrice + tip;

    return {
      'clientName': apt['clients'] != null
          ? apt['clients']['full_name']
          : lang.labelUnknownClient,
      'clientAddress': apt['clients'] != null
          ? apt['clients']['address']
          : null,
      'vehicleInfo': apt['vehicles'] != null
          ? "${apt['vehicles']['model']} - ${apt['vehicles']['category'] ?? lang.labelCategoryNoCategory}"
          : lang.labelUnknownVehicle,
      'serviceNames': serviceNames,
      'totalPrice': grandTotal,
      'status': apt['status'],
      'isCompleted': apt['status'] == 'concluido',
      'isCancelled': apt['status'] == 'cancelado',
    };
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AppBackend.client.auth.currentUser;
    final lang = AppLocalizations.of(context)!;
    final String displayName =
        currentUser?.userMetadata?['full_name'] ?? lang.labelDefaultUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const Padding(
          padding: EdgeInsets.all(8.0),
          child: UserProfileMenu(),
        ),
        centerTitle: true,
        title: Image.asset(
          'assets/images/logo_symbol.png',
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Text(lang.appTitle),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.shopping_cart_outlined,
              color: AppColors.accent,
            ),
            tooltip: lang.tooltipShop, // <-- TRADUZIDO AQUI
            onPressed: _openShop,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.language),
            onSelected: (String langCode) =>
                MyApp.setLocale(context, Locale(langCode)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'en', child: Text('🇺🇸 English')),
              PopupMenuItem(value: 'pt', child: Text('🇧🇷 Português')),
              PopupMenuItem(value: 'es', child: Text('🇪🇸 Español')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      floatingActionButton: _buildFab(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboardData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child:
                          (_isAnnouncementActive &&
                              !_userClosedAnnouncement &&
                              _announcementMessage.isNotEmpty)
                          ? Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.campaign,
                                    color: Colors.orange,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          AppLocalizations.of(
                                                context,
                                              )?.msgImportantNotice ??
                                              'Aviso Importante',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.orange,
                                            fontSize: 12,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _announcementMessage,
                                          style: TextStyle(
                                            color: Colors.grey.shade800,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _userClosedAnnouncement = true;
                                      });
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.grey,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 20.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "${lang.labelHello}, $displayName",
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(
                          Icons.today,
                          color: AppColors.accent,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "${lang.agendaToday} ($_todayAppointmentsCount)",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildAppointmentList(
                      _todayAppointments,
                      isToday: true,
                      emptyMsg: lang.agendaEmptyToday,
                    ),
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_month,
                          color: Colors.grey,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          lang.agendaUpcoming,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildAppointmentList(
                      _upcomingAppointments,
                      isToday: false,
                      emptyMsg: lang.agendaEmptyUpcoming,
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFab() {
    final lang = AppLocalizations.of(context)!;
    return PopupMenuButton<String>(
      offset: const Offset(0, -200),
      tooltip: lang.btnNew,
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.accent,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
      onSelected: (value) {
        Widget screen;
        if (value == 'cliente')
          screen = const AddClientScreen();
        else if (value == 'carro')
          screen = const AddVehicleScreen();
        else
          screen = const AddAppointmentScreen();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ).then((_) => _loadDashboardData());
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'cliente',
          child: Row(
            children: [
              const Icon(Icons.person_add, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(lang.titleNewClient),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'carro',
          child: Row(
            children: [
              const Icon(Icons.directions_car, color: AppColors.primary),
              const SizedBox(width: 10),
              Text(lang.titleNewVehicle),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'agendamento',
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.accent),
              const SizedBox(width: 10),
              Text(lang.titleNewAppointment),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentList(
    List<Map<String, dynamic>> list, {
    required bool isToday,
    required String emptyMsg,
  }) {
    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(
              isToday ? Icons.check_circle_outline : Icons.event_busy,
              size: 40,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            Text(emptyMsg, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final lang = AppLocalizations.of(context)!;
    final currencySymbol = NumberFormat.simpleCurrency(name: '').currencySymbol;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final apt = list[index];
        final data = _processAppointmentData(apt);
        final String status = data['status'] ?? 'pendente';
        final bool isCancelled = data['isCancelled'];
        final bool hasAddress =
            data['clientAddress'] != null &&
            data['clientAddress'].toString().trim().isNotEmpty;

        IconData actionIcon;
        Color actionColor;
        String tooltip;
        VoidCallback? onPressed;

        if (isCancelled) {
          actionIcon = Icons.refresh;
          actionColor = Colors.grey;
          tooltip = lang.btnReactivate;
          onPressed = () {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(lang.dialogReactivateTitle),
                content: Text(lang.dialogReactivateContent),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(lang.btnCancel),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _updateStatus(apt['id'], 'pendente');
                    },
                    child: Text(lang.btnReactivate),
                  ),
                ],
              ),
            );
          };
        } else if (status == 'pendente') {
          actionIcon = Icons.play_arrow_rounded;
          actionColor = Colors.orange;
          tooltip = lang.btnStartService;
          onPressed = () => _updateStatus(apt['id'], 'em_andamento');
        } else if (status == 'em_andamento') {
          actionIcon = Icons.playlist_add_check_rounded;
          actionColor = Colors.blue;
          tooltip = lang.titleChecklist;
          onPressed = () => _showChecklistDialog(apt);
        } else {
          actionIcon = Icons.check_circle;
          actionColor = AppColors.success;
          tooltip = lang.tooltipDetails;
          onPressed = () {};
        }

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            leading: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isCancelled
                    ? Colors.grey.shade200
                    : (isToday
                          ? AppColors.accent.withValues(alpha: 0.15)
                          : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(apt['start_time']),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCancelled
                          ? Colors.grey
                          : (isToday ? AppColors.primary : Colors.grey[700]),
                      decoration: isCancelled
                          ? TextDecoration.lineThrough
                          : null,
                    ),
                  ),
                  if (!isToday)
                    Text(
                      DateFormat(
                        'dd/MM',
                      ).format(DateTime.parse(apt['start_time']).toLocal()),
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                ],
              ),
            ),
            title: Text(
              data['clientName'],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                decoration: isCancelled ? TextDecoration.lineThrough : null,
                color: isCancelled ? Colors.grey : Colors.black,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 14,
                      color: isCancelled ? Colors.grey : Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        "${data['vehicleInfo']}",
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCancelled ? Colors.grey : Colors.grey[800],
                        ),
                      ),
                    ),
                  ],
                ),
                if (data['serviceNames'].toString().isNotEmpty)
                  Text(
                    "${data['serviceNames']}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (data['totalPrice'] > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      "$currencySymbol ${data['totalPrice'].toStringAsFixed(2)}",
                      style: TextStyle(
                        color: isCancelled ? Colors.grey : AppColors.success,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        decoration: isCancelled
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data['isCompleted'] && hasAddress)
                  IconButton(
                    icon: const Icon(Icons.map, color: Colors.blue, size: 24),
                    tooltip: lang.btnOpenMap,
                    onPressed: () => _openMap(data['clientAddress']),
                  ),
                IconButton(
                  icon: Icon(actionIcon, color: actionColor, size: 28),
                  tooltip: tooltip,
                  onPressed: onPressed,
                ),

                if (!isCancelled)
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                    onSelected: (value) {
                      if (value == 'cancel') {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(lang.btnCancelAppointment),
                            content: Text(lang.msgConfirmCancel),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(lang.btnCancel),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.error,
                                ),
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _updateStatus(apt['id'], 'cancelado');
                                },
                                child: Text(lang.btnConfirm),
                              ),
                            ],
                          ),
                        );
                      } else if (value == 'map') {
                        _openMap(data['clientAddress']);
                      } else if (value == 'edit_completed') {
                        _showEditCompletedDialog(apt);
                      }
                    },
                    itemBuilder: (context) => [
                      if (data['isCompleted'])
                        PopupMenuItem(
                          value: 'edit_completed',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.edit_note,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                lang.menuEditPaymentServices,
                              ), // <-- TRADUZIDO AQUI
                            ],
                          ),
                        ),
                      if (!data['isCompleted'] && hasAddress)
                        PopupMenuItem(
                          value: 'map',
                          child: Row(
                            children: [
                              const Icon(Icons.map, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(lang.btnOpenMap),
                            ],
                          ),
                        ),
                      if (!data['isCompleted'])
                        PopupMenuItem(
                          value: 'cancel',
                          child: Row(
                            children: [
                              const Icon(
                                Icons.cancel_presentation,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Text(lang.btnCancelAppointment),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

//teste de deploy
