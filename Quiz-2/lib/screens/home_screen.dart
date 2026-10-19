import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/patient.dart';
import '../theme/app_theme.dart';
import '../widgets/animations.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/empty_state.dart';
import '../widgets/patient_card.dart';
import '../widgets/stat_card.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _db = DatabaseHelper.instance;
  final _searchCtrl = TextEditingController();

  List<Patient> _patients = [];
  int _total = 0, _docs = 0, _today = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final patients = await _db.getPatients(query: _searchCtrl.text);
    final total = await _db.countPatients();
    final docs = await _db.countDocuments();
    final today = await _db.countToday();
    if (!mounted) return;
    setState(() {
      _patients = patients;
      _total = total;
      _docs = docs;
      _today = today;
      _loading = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _openForm() async {
    final saved = await Navigator.push<bool>(
        context, slideUpRoute(const PatientFormScreen()));
    if (saved == true) {
      _load();
      if (mounted) _snack('Patient added successfully');
    }
  }

  Future<void> _openDetail(Patient p) async {
    await Navigator.push(context, slideUpRoute(PatientDetailScreen(patient: p)));
    _load();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.primaryDark,
      ));
  }

  Future<void> _delete(Patient p) async {
    setState(() => _patients.removeWhere((x) => x.id == p.id));
    await _db.deletePatient(p);
    await _load();
    if (mounted) _snack('${p.name} deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.elasticOut,
        builder: (_, v, child) => Transform.scale(scale: v, child: child),
        child: FloatingActionButton.extended(
          onPressed: _openForm,
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Patient',
              style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                child: Row(
                  children: [
                    const Text('Patients',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        key: ValueKey(_patients.length),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${_patients.length}',
                            style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_patients.isEmpty)
              SliverToBoxAdapter(
                child: EmptyState(
                  title: _searchCtrl.text.isEmpty
                      ? 'No patients yet'
                      : 'No results found',
                  subtitle: _searchCtrl.text.isEmpty
                      ? 'Tap "Add Patient" to create your first patient record.'
                      : 'Try searching with a different name, phone or condition.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList.builder(
                  itemCount: _patients.length,
                  itemBuilder: (context, i) {
                    final p = _patients[i];
                    return FadeSlideIn(
                      key: ValueKey('card_${p.id}'),
                      index: i,
                      child: Dismissible(
                        key: ValueKey('dismiss_${p.id}'),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) => confirmDelete(
                          context,
                          title: 'Delete patient?',
                          message:
                              '${p.name} and all attached documents will be removed permanently.',
                        ),
                        onDismissed: (_) => _delete(p),
                        background: Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.only(right: 26),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: AppColors.danger,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.delete_rounded,
                              color: Colors.white, size: 28),
                        ),
                        child:
                            PatientCard(patient: p, onTap: () => _openDetail(p)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.gradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(36)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 18, 20, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            offset: -20,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 14)),
                      const SizedBox(height: 2),
                      const Text('Welcome, Doctor',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.local_hospital_rounded,
                      color: Colors.white, size: 26),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            index: 1,
            child: Row(
              children: [
                Expanded(
                    child: StatCard(
                        icon: Icons.people_alt_rounded,
                        value: _total,
                        label: 'Patients')),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        icon: Icons.folder_copy_rounded,
                        value: _docs,
                        label: 'Documents')),
                const SizedBox(width: 12),
                Expanded(
                    child: StatCard(
                        icon: Icons.today_rounded,
                        value: _today,
                        label: 'New today')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FadeSlideIn(
            index: 2,
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Search name, phone or condition',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _searchCtrl.clear();
                          _load();
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
