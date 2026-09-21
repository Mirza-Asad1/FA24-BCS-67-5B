import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const SalaryCalculatorApp());
}

class SalaryCalculatorApp extends StatelessWidget {
  const SalaryCalculatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Salary Calculator',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C63FF),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const SalaryCalculatorScreen(),
    );
  }
}

// ─────────────────────────────────────────────
// Model
// ─────────────────────────────────────────────
class SalaryBreakdown {
  final double basicSalary;
  final double travelAllowance;
  final double residentialAllowance;
  final double medicalAllowance;
  final double grossSalary;
  final double taxDeduction;
  final double netSalary;
  final double taxRate;

  const SalaryBreakdown({
    required this.basicSalary,
    required this.travelAllowance,
    required this.residentialAllowance,
    required this.medicalAllowance,
    required this.grossSalary,
    required this.taxDeduction,
    required this.netSalary,
    required this.taxRate,
  });

  static SalaryBreakdown calculate({
    required double basicSalary,
    required double travelAllowance,
    required double residentialAllowance,
    required double medicalAllowance,
  }) {
    final gross =
        basicSalary + travelAllowance + residentialAllowance + medicalAllowance;
    final taxRate = _computeTaxRate(gross);
    final tax = gross * taxRate;
    return SalaryBreakdown(
      basicSalary: basicSalary,
      travelAllowance: travelAllowance,
      residentialAllowance: residentialAllowance,
      medicalAllowance: medicalAllowance,
      grossSalary: gross,
      taxDeduction: tax,
      netSalary: gross - tax,
      taxRate: taxRate,
    );
  }

  /// Simple progressive tax brackets (monthly gross in PKR)
  static double _computeTaxRate(double gross) {
    if (gross <= 50000) return 0.0;
    if (gross <= 100000) return 0.05;
    if (gross <= 200000) return 0.10;
    if (gross <= 400000) return 0.15;
    if (gross <= 600000) return 0.20;
    return 0.25;
  }
}

// ─────────────────────────────────────────────
// Screen
// ─────────────────────────────────────────────
class SalaryCalculatorScreen extends StatefulWidget {
  const SalaryCalculatorScreen({super.key});

  @override
  State<SalaryCalculatorScreen> createState() => _SalaryCalculatorScreenState();
}

class _SalaryCalculatorScreenState extends State<SalaryCalculatorScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _basicCtrl = TextEditingController();
  final _travelCtrl = TextEditingController();
  final _residentialCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();

  SalaryBreakdown? _result;
  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _basicCtrl.dispose();
    _travelCtrl.dispose();
    _residentialCtrl.dispose();
    _medicalCtrl.dispose();
    super.dispose();
  }

  void _calculate() {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _result = SalaryBreakdown.calculate(
        basicSalary: double.tryParse(_basicCtrl.text) ?? 0,
        travelAllowance: double.tryParse(_travelCtrl.text) ?? 0,
        residentialAllowance: double.tryParse(_residentialCtrl.text) ?? 0,
        medicalAllowance: double.tryParse(_medicalCtrl.text) ?? 0,
      );
    });
    _animCtrl.forward(from: 0);
  }

  void _reset() {
    setState(() {
      _basicCtrl.clear();
      _travelCtrl.clear();
      _residentialCtrl.clear();
      _medicalCtrl.clear();
      _result = null;
    });
    _animCtrl.reset();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF6C63FF), Color(0xFF48CAE4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8F9FF),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(32),
                    ),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _SectionTitle(
                              icon: Icons.account_balance_wallet_rounded,
                              label: 'Enter Salary Details',
                            ),
                            const SizedBox(height: 20),
                            _InputCard(
                              controller: _basicCtrl,
                              label: 'Basic Salary',
                              hint: 'e.g. 150000',
                              icon: Icons.attach_money_rounded,
                              color: const Color(0xFF6C63FF),
                              required: true,
                            ),
                            const SizedBox(height: 22),
                            const _SectionTitle(
                              icon: Icons.add_circle_outline_rounded,
                              label: 'Allowances',
                            ),
                            const SizedBox(height: 14),
                            _InputCard(
                              controller: _travelCtrl,
                              label: 'Travel Allowance',
                              hint: 'e.g. 10000',
                              icon: Icons.directions_car_rounded,
                              color: const Color(0xFF43B89C),
                            ),
                            const SizedBox(height: 14),
                            _InputCard(
                              controller: _residentialCtrl,
                              label: 'Residential Allowance',
                              hint: 'e.g. 20000',
                              icon: Icons.home_rounded,
                              color: const Color(0xFFFF6B6B),
                            ),
                            const SizedBox(height: 14),
                            _InputCard(
                              controller: _medicalCtrl,
                              label: 'Medical Allowance',
                              hint: 'e.g. 5000',
                              icon: Icons.local_hospital_rounded,
                              color: const Color(0xFFFFB347),
                            ),
                            const SizedBox(height: 28),
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    label: 'Calculate',
                                    icon: Icons.calculate_rounded,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF6C63FF),
                                        Color(0xFF48CAE4),
                                      ],
                                    ),
                                    onTap: _calculate,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                _ResetButton(onTap: _reset),
                              ],
                            ),
                            const SizedBox(height: 28),
                            if (_result != null)
                              FadeTransition(
                                opacity: _fadeAnim,
                                child: SlideTransition(
                                  position: _slideAnim,
                                  child: _ResultCard(breakdown: _result!),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.monetization_on_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Salary Calculator',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Know your take-home pay',
                style: TextStyle(color: Colors.white70, fontSize: 12.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF6C63FF)),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D2D3A),
          ),
        ),
      ],
    );
  }
}

class _InputCard extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;
  final bool required;

  const _InputCard({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
    this.required = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
        ],
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2D2D3A),
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          labelStyle: TextStyle(color: color, fontWeight: FontWeight.w500),
          prefixIcon: Container(
            margin: const EdgeInsets.all(10),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          suffixText: 'PKR',
          suffixStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: color, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.6),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        validator: required
            ? (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Basic salary is required';
                }
                if (double.tryParse(v) == null) {
                  return 'Enter a valid number';
                }
                return null;
              }
            : null,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6C63FF).withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ResetButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.refresh_rounded,
          color: Color(0xFF6C63FF),
          size: 22,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Result Card
// ─────────────────────────────────────────────
class _ResultCard extends StatelessWidget {
  final SalaryBreakdown breakdown;
  const _ResultCard({required this.breakdown});

  static String _fmt(double value) =>
      'PKR ${value.toStringAsFixed(0).replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')}';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Net Salary Hero ──
        Container(
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6C63FF), Color(0xFF9B59B6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6C63FF).withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white70,
                size: 32,
              ),
              const SizedBox(height: 10),
              const Text(
                'Net Take-Home Salary',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Text(
                _fmt(breakdown.netSalary),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tax Rate Applied: ${(breakdown.taxRate * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Breakdown Card ──
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                blurRadius: 18,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionTitle(
                icon: Icons.list_alt_rounded,
                label: 'Salary Breakdown',
              ),
              const SizedBox(height: 16),
              _BreakdownRow(
                icon: Icons.attach_money_rounded,
                color: const Color(0xFF6C63FF),
                label: 'Basic Salary',
                amount: breakdown.basicSalary,
                isPositive: true,
              ),
              const _RowDivider(),
              _BreakdownRow(
                icon: Icons.directions_car_rounded,
                color: const Color(0xFF43B89C),
                label: 'Travel Allowance',
                amount: breakdown.travelAllowance,
                isPositive: true,
              ),
              const _RowDivider(),
              _BreakdownRow(
                icon: Icons.home_rounded,
                color: const Color(0xFFFF6B6B),
                label: 'Residential Allowance',
                amount: breakdown.residentialAllowance,
                isPositive: true,
              ),
              const _RowDivider(),
              _BreakdownRow(
                icon: Icons.local_hospital_rounded,
                color: const Color(0xFFFFB347),
                label: 'Medical Allowance',
                amount: breakdown.medicalAllowance,
                isPositive: true,
              ),
              const SizedBox(height: 14),

              // Gross
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _BreakdownRow(
                  icon: Icons.summarize_rounded,
                  color: const Color(0xFF6C63FF),
                  label: 'Gross Salary',
                  amount: breakdown.grossSalary,
                  isPositive: true,
                  bold: true,
                ),
              ),
              const SizedBox(height: 8),

              // Tax
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withOpacity(0.07),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _BreakdownRow(
                  icon: Icons.remove_circle_outline_rounded,
                  color: const Color(0xFFFF6B6B),
                  label:
                      'Tax Deduction (${(breakdown.taxRate * 100).toStringAsFixed(0)}%)',
                  amount: breakdown.taxDeduction,
                  isPositive: false,
                  bold: true,
                ),
              ),
              const SizedBox(height: 14),
              const Divider(thickness: 1.2, color: Color(0xFFE8E8F0)),
              const SizedBox(height: 10),

              // Net
              _BreakdownRow(
                icon: Icons.account_balance_wallet_rounded,
                color: const Color(0xFF6C63FF),
                label: 'Net Salary',
                amount: breakdown.netSalary,
                isPositive: true,
                bold: true,
                fontSize: 16,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Tax Info Banner ──
        _TaxInfoBanner(
          taxRate: breakdown.taxRate,
          gross: breakdown.grossSalary,
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final double amount;
  final bool isPositive;
  final bool bold;
  final double fontSize;

  const _BreakdownRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.amount,
    required this.isPositive,
    this.bold = false,
    this.fontSize = 13.5,
  });

  @override
  Widget build(BuildContext context) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    final amountStr = amount == 0
        ? '—'
        : '${isPositive ? '+' : '-'} PKR $formatted';

    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: const Color(0xFF2D2D3A),
            ),
          ),
        ),
        Text(
          amountStr,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
            color: isPositive
                ? const Color(0xFF43B89C)
                : const Color(0xFFFF6B6B),
          ),
        ),
      ],
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(color: Colors.grey.shade100, thickness: 1, height: 1),
  );
}

class _TaxInfoBanner extends StatelessWidget {
  final double taxRate;
  final double gross;
  const _TaxInfoBanner({required this.taxRate, required this.gross});

  String get _bracket {
    if (gross <= 50000) return 'No Tax (≤ PKR 50,000/month)';
    if (gross <= 100000) return '5% Bracket  (PKR 50k – 100k)';
    if (gross <= 200000) return '10% Bracket (PKR 100k – 200k)';
    if (gross <= 400000) return '15% Bracket (PKR 200k – 400k)';
    if (gross <= 600000) return '20% Bracket (PKR 400k – 600k)';
    return '25% Bracket (> PKR 600k)';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB347).withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFFFFB347),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tax Bracket Applied',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Color(0xFF7B5800),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _bracket,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9E6B00),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
