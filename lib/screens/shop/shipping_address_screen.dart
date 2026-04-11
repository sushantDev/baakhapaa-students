import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../helpers/helpers.dart';
import '../../models/shipping.dart';
import '../../providers/delivery_provider.dart';
import '../../widgets/header.dart';
import '../../utils/debug_logger.dart';

/// Screen for managing international shipping addresses.
/// Returns the selected [ShippingAddress] via Navigator.pop.
class ShippingAddressScreen extends StatefulWidget {
  static const routeName = '/shipping-address';

  const ShippingAddressScreen({Key? key}) : super(key: key);

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  var _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _isInit = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Provider.of<DeliveryProvider>(context, listen: false)
              .fetchAddresses();
        }
      });
    }
  }

  void _openAddForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAddressSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: header(context: context, titleText: 'Shipping Address'),
      body: Consumer<DeliveryProvider>(
        builder: (ctx, delivery, _) {
          if (delivery.isLoadingAddresses && delivery.addresses.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (delivery.addresses.isEmpty) {
            return _buildEmpty(context);
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: delivery.addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) {
                    final addr = delivery.addresses[i];
                    final isSelected = delivery.selectedAddress?.id == addr.id;
                    return _AddressTile(
                      address: addr,
                      isSelected: isSelected,
                      onTap: () {
                        delivery.selectAddress(addr);
                      },
                      onDelete: () async {
                        await delivery.deleteAddress(addr.id);
                        if (mounted) {
                          showScaffoldMessenger(context, 'Address removed.');
                        }
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _openAddForm,
                      icon: const Icon(Icons.add),
                      label: const Text('Add New Address'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: delivery.selectedAddress != null
                          ? () => Navigator.of(context)
                              .pop(delivery.selectedAddress)
                          : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text(
                        'Continue with Selected Address',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DeliveryProvider>(
        builder: (_, delivery, __) => delivery.addresses.isEmpty
            ? const SizedBox.shrink()
            : FloatingActionButton(
                onPressed: _openAddForm,
                backgroundColor: Colors.deepPurple,
                child: const Icon(Icons.add, color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off_outlined,
              size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No shipping addresses yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add an address to ship internationally from Nepal.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _openAddForm,
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Address tile ─────────────────────────────────────────────────────────────

class _AddressTile extends StatelessWidget {
  final ShippingAddress address;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _AddressTile({
    required this.address,
    required this.isSelected,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? Colors.deepPurple.withOpacity(0.04)
              : Theme.of(context).cardColor,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        isSelected ? Colors.deepPurple : Colors.grey.shade400,
                    width: 2,
                  ),
                  color: isSelected ? Colors.deepPurple : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 14)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          address.recipientName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (address.isDefault) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'Default',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.deepPurple,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.phone,
                      style:
                          TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address.formattedAddress,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                          height: 1.4),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    color: Colors.red.shade400, size: 20),
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Address?'),
        content: Text('Remove address for ${address.recipientName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onDelete();
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ─── Add Address Bottom Sheet ─────────────────────────────────────────────────

/// Curated list of (countryCode, countryName) pairs covering most destinations.
const _kCountries = [
  ('AU', 'Australia'),
  ('AT', 'Austria'),
  ('BD', 'Bangladesh'),
  ('BE', 'Belgium'),
  ('BR', 'Brazil'),
  ('CA', 'Canada'),
  ('CN', 'China'),
  ('CZ', 'Czech Republic'),
  ('DK', 'Denmark'),
  ('FI', 'Finland'),
  ('FR', 'France'),
  ('DE', 'Germany'),
  ('GH', 'Ghana'),
  ('GR', 'Greece'),
  ('HK', 'Hong Kong'),
  ('HU', 'Hungary'),
  ('IN', 'India'),
  ('ID', 'Indonesia'),
  ('IE', 'Ireland'),
  ('IL', 'Israel'),
  ('IT', 'Italy'),
  ('JP', 'Japan'),
  ('KE', 'Kenya'),
  ('KW', 'Kuwait'),
  ('LK', 'Sri Lanka'),
  ('MY', 'Malaysia'),
  ('MX', 'Mexico'),
  ('NL', 'Netherlands'),
  ('NZ', 'New Zealand'),
  ('NG', 'Nigeria'),
  ('NP', 'Nepal'),
  ('NO', 'Norway'),
  ('OM', 'Oman'),
  ('PK', 'Pakistan'),
  ('PE', 'Peru'),
  ('PH', 'Philippines'),
  ('PL', 'Poland'),
  ('PT', 'Portugal'),
  ('QA', 'Qatar'),
  ('RO', 'Romania'),
  ('SA', 'Saudi Arabia'),
  ('SG', 'Singapore'),
  ('ZA', 'South Africa'),
  ('KR', 'South Korea'),
  ('ES', 'Spain'),
  ('SE', 'Sweden'),
  ('CH', 'Switzerland'),
  ('TW', 'Taiwan'),
  ('TH', 'Thailand'),
  ('TR', 'Turkey'),
  ('AE', 'United Arab Emirates'),
  ('GB', 'United Kingdom'),
  ('US', 'United States'),
  ('VN', 'Vietnam'),
];

class _AddAddressSheet extends StatefulWidget {
  @override
  State<_AddAddressSheet> createState() => _AddAddressSheetState();
}

class _AddAddressSheetState extends State<_AddAddressSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _isSaving = false;
  bool _isDefault = false;

  String? _selectedCountryCode;
  String? _selectedCountryName;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _line1Ctrl = TextEditingController();
  final _line2Ctrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _postalCtrl = TextEditingController();

  // Validation key for country field
  final _countryFieldKey = GlobalKey<FormFieldState>();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _line1Ctrl.dispose();
    _line2Ctrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _postalCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCountryCode == null) {
      showScaffoldMessenger(context, 'Please select a country.');
      return;
    }

    setState(() => _isSaving = true);
    final delivery = Provider.of<DeliveryProvider>(context, listen: false);

    final data = {
      'recipient_name': _nameCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'address_line1': _line1Ctrl.text.trim(),
      if (_line2Ctrl.text.trim().isNotEmpty)
        'address_line2': _line2Ctrl.text.trim(),
      'city': _cityCtrl.text.trim(),
      if (_stateCtrl.text.trim().isNotEmpty)
        'state_province': _stateCtrl.text.trim(),
      'postal_code': _postalCtrl.text.trim(),
      'country_code': _selectedCountryCode!,
      'country_name': _selectedCountryName!,
      'is_default': _isDefault,
    };

    try {
      final address = await delivery.addAddress(data);
      if (!mounted) return;
      if (address != null) {
        Navigator.of(context).pop();
        showScaffoldMessenger(context, 'Address added successfully.');
      } else {
        showScaffoldMessenger(
            context, 'Failed to add address. Please try again.');
      }
    } catch (e) {
      DebugLogger.error('_AddAddressSheet save error: $e');
      if (mounted) showScaffoldMessenger(context, 'Error saving address.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _pickCountry() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CountryPickerSheet(
        selected: _selectedCountryCode,
        onSelect: (code, name) {
          setState(() {
            _selectedCountryCode = code;
            _selectedCountryName = name;
          });
          _countryFieldKey.currentState?.validate();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111214) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C1E22) : const Color(0xFFF7F8FA);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.grey.withValues(alpha: 0.15);
    final labelColor = isDark ? Colors.white70 : Colors.grey.shade700;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 4),

          // ── Gradient header ───────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add_location_alt_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'New Shipping Address',
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        'Fill in your international delivery details',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: labelColor,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.grey.shade500),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          Divider(
              height: 1, color: isDark ? Colors.white10 : Colors.grey.shade200),

          // ── Scrollable form ───────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Section: Recipient ──────────────────────────────────
                    _SectionHeader(
                        icon: Icons.person_outline_rounded,
                        label: 'Recipient',
                        isDark: isDark),
                    const SizedBox(height: 10),
                    _styledField(
                      controller: _nameCtrl,
                      label: 'Full Name',
                      hint: 'Who receives the package?',
                      icon: Icons.badge_outlined,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _styledField(
                      controller: _phoneCtrl,
                      label: 'Phone Number',
                      hint: '+1 234 567 8900',
                      icon: Icons.phone_outlined,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Section: Address ────────────────────────────────────
                    _SectionHeader(
                        icon: Icons.home_outlined,
                        label: 'Address',
                        isDark: isDark),
                    const SizedBox(height: 10),
                    _styledField(
                      controller: _line1Ctrl,
                      label: 'Street / Building',
                      hint: '123 Main Street, Apt 4B',
                      icon: Icons.apartment_outlined,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    _styledField(
                      controller: _line2Ctrl,
                      label: 'Address Line 2',
                      hint: 'Floor, Suite, Unit (optional)',
                      icon: Icons.add_road_outlined,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _styledField(
                            controller: _cityCtrl,
                            label: 'City',
                            hint: 'City name',
                            icon: Icons.location_city_outlined,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Required'
                                : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _styledField(
                            controller: _stateCtrl,
                            label: 'State / Province',
                            hint: 'Optional',
                            icon: Icons.map_outlined,
                            isDark: isDark,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _styledField(
                      controller: _postalCtrl,
                      label: 'Postal / ZIP Code',
                      hint: 'e.g. 10001',
                      icon: Icons.markunread_mailbox_outlined,
                      isDark: isDark,
                      cardBg: cardBg,
                      borderColor: borderColor,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'[A-Za-z0-9\- ]'))
                      ],
                      textInputAction: TextInputAction.next,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),

                    const SizedBox(height: 20),

                    // ── Section: Country ────────────────────────────────────
                    _SectionHeader(
                        icon: Icons.public_outlined,
                        label: 'Country',
                        isDark: isDark),
                    const SizedBox(height: 10),

                    // Country picker tap target
                    FormField<String>(
                      key: _countryFieldKey,
                      initialValue: _selectedCountryCode,
                      validator: (_) => _selectedCountryCode == null
                          ? 'Please select a country'
                          : null,
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: _pickCountry,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: field.hasError
                                      ? Colors.red
                                      : _selectedCountryCode != null
                                          ? const Color(0xFF7C3AED)
                                              .withValues(alpha: 0.6)
                                          : borderColor,
                                  width: _selectedCountryCode != null ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: _selectedCountryCode != null
                                          ? const Color(0xFF7C3AED)
                                              .withValues(alpha: 0.12)
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.06)
                                              : Colors.grey.shade100),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: _selectedCountryCode != null
                                          ? Text(
                                              _flagEmoji(_selectedCountryCode!),
                                              style:
                                                  const TextStyle(fontSize: 20),
                                            )
                                          : Icon(Icons.flag_outlined,
                                              size: 18,
                                              color: isDark
                                                  ? Colors.white38
                                                  : Colors.grey.shade500),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedCountryCode != null
                                              ? _selectedCountryName!
                                              : 'Select Country',
                                          style: GoogleFonts.inter(
                                            fontSize: 15,
                                            fontWeight:
                                                _selectedCountryCode != null
                                                    ? FontWeight.w600
                                                    : FontWeight.w400,
                                            color: _selectedCountryCode != null
                                                ? (isDark
                                                    ? Colors.white
                                                    : Colors.black87)
                                                : (isDark
                                                    ? Colors.white38
                                                    : Colors.grey.shade500),
                                          ),
                                        ),
                                        if (_selectedCountryCode != null)
                                          Text(
                                            _selectedCountryCode!,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              color: const Color(0xFF7C3AED),
                                              fontWeight: FontWeight.w600,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey.shade500,
                                    size: 22,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (field.hasError)
                            Padding(
                              padding: const EdgeInsets.only(top: 6, left: 4),
                              child: Text(
                                field.errorText!,
                                style: TextStyle(
                                    color: Colors.red.shade600, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Default toggle ──────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: _isDefault
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.08)
                            : cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: _isDefault
                              ? const Color(0xFF7C3AED).withValues(alpha: 0.4)
                              : borderColor,
                          width: _isDefault ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: _isDefault
                                  ? const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.12)
                                  : (isDark
                                      ? Colors.white.withValues(alpha: 0.06)
                                      : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.star_outline_rounded,
                              size: 18,
                              color: _isDefault
                                  ? const Color(0xFF7C3AED)
                                  : (isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Set as default',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                                Text(
                                  'Pre-selected at checkout',
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: labelColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: _isDefault,
                            activeColor: const Color(0xFF7C3AED),
                            onChanged: (val) =>
                                setState(() => _isDefault = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Save button ─────────────────────────────────────────
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: _isSaving
                            ? null
                            : const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF9F67FF)],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                        color: _isSaving ? Colors.grey.shade400 : null,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _isSaving
                            ? null
                            : [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: _isSaving ? null : _save,
                          child: Center(
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.save_alt_rounded,
                                          color: Colors.white, size: 20),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Save Address',
                                        style: GoogleFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color cardBg,
    required Color borderColor,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? Colors.white54 : Colors.grey.shade600,
        ),
        hintText: hint,
        hintStyle: GoogleFonts.inter(
          fontSize: 13,
          color: isDark ? Colors.white24 : Colors.grey.shade400,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Icon(icon,
              size: 20, color: isDark ? Colors.white38 : Colors.grey.shade500),
        ),
        filled: true,
        fillColor: cardBg,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF7C3AED), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: GoogleFonts.inter(fontSize: 11, color: Colors.red.shade600),
      ),
    );
  }

  /// Convert ISO country code to flag emoji.
  String _flagEmoji(String code) {
    return code.toUpperCase().split('').map((c) {
      return String.fromCharCode(c.codeUnitAt(0) + 127397);
    }).join();
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _SectionHeader(
      {required this.icon, required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: const Color(0xFF7C3AED)),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF7C3AED),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200,
          ),
        ),
      ],
    );
  }
}

// ── Country picker sheet ────────────────────────────────────────────────────────

class _CountryPickerSheet extends StatefulWidget {
  final String? selected;
  final void Function(String code, String name) onSelect;

  const _CountryPickerSheet({required this.selected, required this.onSelect});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<(String, String)> _filtered = List.from(_kCountries);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String q) {
    final query = q.toLowerCase();
    setState(() {
      _filtered = _kCountries
          .where((e) =>
              e.$1.toLowerCase().contains(query) ||
              e.$2.toLowerCase().contains(query))
          .toList();
    });
  }

  String _flagEmoji(String code) {
    return code.toUpperCase().split('').map((c) {
      return String.fromCharCode(c.codeUnitAt(0) + 127397);
    }).join();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF111214) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1C1E22) : const Color(0xFFF7F8FA);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: GoogleFonts.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark ? Colors.white38 : Colors.grey.shade500),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              autofocus: true,
              style: GoogleFonts.inter(
                  fontSize: 14, color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: 'Search country…',
                hintStyle: GoogleFonts.inter(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : Colors.grey.shade500),
                prefixIcon: Icon(Icons.search_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey.shade500),
                filled: true,
                fillColor: cardBg,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _filtered.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: GoogleFonts.inter(
                          color:
                              isDark ? Colors.white38 : Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filtered.length,
                    itemBuilder: (_, i) {
                      final (code, name) = _filtered[i];
                      final isSelected = widget.selected == code;
                      return ListTile(
                        onTap: () {
                          widget.onSelect(code, name);
                          Navigator.pop(context);
                        },
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected
                            ? const Color(0xFF7C3AED).withValues(alpha: 0.1)
                            : Colors.transparent,
                        leading: Text(_flagEmoji(code),
                            style: const TextStyle(fontSize: 24)),
                        title: Text(
                          name,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF7C3AED)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded,
                                color: Color(0xFF7C3AED), size: 20)
                            : Text(
                                code,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white38
                                      : Colors.grey.shade500,
                                  letterSpacing: 1,
                                ),
                              ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
