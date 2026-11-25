import 'package:vlinix/data/app_backend.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vlinix/l10n/app_localizations.dart';
import 'package:vlinix/theme/app_colors.dart';
import 'add_vehicle_screen.dart';

class ClientDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> clientData;

  const ClientDetailsScreen({super.key, required this.clientData});

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _clientVehicles = [];

  @override
  void initState() {
    super.initState();
    _loadClientVehicles();
  }

  Future<void> _loadClientVehicles() async {
    setState(() => _isLoading = true);
    try {
      final data = await AppBackend.client
          .from('vehicles')
          .select()
          .eq('client_id', widget.clientData['id'])
          .order('model');

      if (mounted) {
        setState(() {
          _clientVehicles = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erro ao carregar veículos do cliente: $e');
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

  Future<void> _deleteVehicle(int vehicleId) async {
    final lang = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.dialogDeleteTitle),
        content: Text(lang.dialogDeleteContent),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              lang.btnCancel,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(lang.btnDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await AppBackend.client.from('vehicles').delete().eq('id', vehicleId);
      _loadClientVehicles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(lang.msgErrorDeleteVehicle),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _navigateToAddEditVehicle({Map<String, dynamic>? vehicle}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddVehicleScreen(
          vehicleToEdit: vehicle,
          preSelectedClientId: widget.clientData['id'],
        ),
      ),
    );
    _loadClientVehicles();
  }

  @override
  Widget build(BuildContext context) {
    final lang = AppLocalizations.of(context)!;
    final client = widget.clientData;
    final hasAddress =
        client['address'] != null &&
        client['address'].toString().trim().isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(lang.titleClientProfile), // <-- TRADUZIDO AQUI
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- CABEÇALHO DO CLIENTE ---
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.1,
                          ),
                          child: Text(
                            client['full_name']
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          client['full_name'],
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (client['phone'] != null &&
                            client['phone'] != '') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                client['phone'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (client['email'] != null &&
                            client['email'] != '') ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.email,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                client['email'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (hasAddress)
                          GestureDetector(
                            onTap: () => _openMap(client['address']),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 16,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    client['address'],
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue,
                                      decoration: TextDecoration.underline,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // --- LISTA DE VEÍCULOS DESSE CLIENTE ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        lang.menuVehicles, // <-- TRADUZIDO AQUI
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(
                          lang.btnRegisterVehicle,
                        ), // <-- TRADUZIDO AQUI
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accent,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                        onPressed: () => _navigateToAddEditVehicle(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  if (_clientVehicles.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.directions_car_filled,
                            size: 48,
                            color: Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            lang.msgClientNoVehicles, // <-- TRADUZIDO AQUI
                            style: TextStyle(color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _clientVehicles.length,
                      itemBuilder: (context, index) {
                        final vehicle = _clientVehicles[index];
                        return Card(
                          elevation: 0,
                          color: Colors.white,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.directions_car,
                                color: AppColors.primary,
                              ),
                            ),
                            title: Text(
                              '${vehicle['model']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${lang.labelCategory}: ${vehicle['category'] ?? lang.labelCategoryNoCategory} • ${lang.labelColor}: ${vehicle['color'] ?? 'N/A'}', // <-- TRADUZIDO AQUI
                            ),
                            trailing: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert,
                                color: Colors.grey,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _navigateToAddEditVehicle(vehicle: vehicle);
                                } else if (value == 'delete') {
                                  _deleteVehicle(vehicle['id']);
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.edit,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(lang.btnEdit),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.delete,
                                        color: AppColors.error,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(lang.btnDelete),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
    );
  }
}
