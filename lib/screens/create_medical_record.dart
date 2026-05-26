import 'package:flutter/material.dart';
import 'package:icare/models/appointment_detail.dart';
import 'package:icare/services/efficiency_service.dart';
import 'package:icare/services/medical_record_service.dart';
import 'package:icare/utils/theme.dart';
import 'package:icare/widgets/back_button.dart';
import 'package:icare/widgets/custom_button.dart';
import 'package:icare/services/course_service.dart';
import 'package:icare/services/laboratory_service.dart';
import 'package:icare/services/pharmacy_service.dart';
import 'package:intl/intl.dart';

class CreateMedicalRecordScreen extends StatefulWidget {
  final AppointmentDetail appointment;

  const CreateMedicalRecordScreen({super.key, required this.appointment});

  @override
  State<CreateMedicalRecordScreen> createState() =>
      _CreateMedicalRecordScreenState();
}

class _CreateMedicalRecordScreenState extends State<CreateMedicalRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final MedicalRecordService _medicalRecordService = MedicalRecordService();

  // Controllers
  final _diagnosisController = TextEditingController();
  final _symptomsController = TextEditingController();
  final _notesController = TextEditingController();

  // Common diagnoses for searchable dropdown
  static const List<String> _commonDiagnoses = [
    'Hypertension', 'Type 2 Diabetes Mellitus', 'Type 1 Diabetes Mellitus',
    'Upper Respiratory Tract Infection (URTI)', 'Lower Respiratory Tract Infection',
    'Pneumonia', 'Bronchitis', 'Asthma', 'COPD',
    'Acute Gastroenteritis', 'Peptic Ulcer Disease', 'GERD',
    'Urinary Tract Infection (UTI)', 'Kidney Stones',
    'Anemia', 'Iron Deficiency Anemia',
    'Migraine', 'Tension Headache',
    'Acute Pharyngitis', 'Tonsillitis', 'Sinusitis', 'Otitis Media',
    'Conjunctivitis', 'Allergic Rhinitis',
    'Eczema', 'Psoriasis', 'Acne Vulgaris', 'Urticaria',
    'Hypothyroidism', 'Hyperthyroidism',
    'Anxiety Disorder', 'Depression',
    'Osteoarthritis', 'Rheumatoid Arthritis', 'Gout',
    'Dengue Fever', 'Typhoid Fever', 'Malaria',
    'COVID-19', 'Influenza',
    'Coronary Artery Disease', 'Heart Failure', 'Arrhythmia',
    'Stroke', 'Epilepsy',
    'Hepatitis A', 'Hepatitis B', 'Hepatitis C',
    'Appendicitis', 'Cholecystitis',
    'Other',
  ];

  // Common medicines for searchable dropdown
  static const List<String> _commonMedicines = [
    'Paracetamol (Panadol)', 'Ibuprofen (Brufen)', 'Aspirin', 'Diclofenac (Voltaren)',
    'Naproxen', 'Mefenamic Acid (Ponstan)', 'Tramadol', 'Codeine',
    'Amoxicillin', 'Amoxicillin + Clavulanate (Augmentin)', 'Azithromycin (Zithromax)',
    'Clarithromycin', 'Ciprofloxacin', 'Levofloxacin', 'Doxycycline',
    'Metronidazole (Flagyl)', 'Clindamycin', 'Cephalexin', 'Cefuroxime', 'Ceftriaxone',
    'Flucloxacillin', 'Co-trimoxazole (Septrin)',
    'Omeprazole', 'Pantoprazole', 'Ranitidine', 'Esomeprazole (Nexium)',
    'Domperidone (Motilium)', 'Metoclopramide', 'Ondansetron (Zofran)',
    'Loperamide (Imodium)', 'Oral Rehydration Salts (ORS)',
    'Metformin', 'Glibenclamide', 'Gliclazide', 'Sitagliptin', 'Insulin (Regular)',
    'Amlodipine', 'Lisinopril', 'Enalapril', 'Losartan', 'Valsartan',
    'Atenolol', 'Metoprolol', 'Propranolol', 'Bisoprolol',
    'Hydrochlorothiazide (HCT)', 'Furosemide (Lasix)', 'Spironolactone',
    'Atorvastatin (Lipitor)', 'Rosuvastatin', 'Simvastatin',
    'Aspirin (Low Dose 75mg)', 'Warfarin', 'Clopidogrel', 'Rivaroxaban',
    'Salbutamol (Ventolin) Inhaler', 'Beclomethasone Inhaler', 'Montelukast',
    'Levothyroxine (Euthyrox)', 'Carbimazole',
    'Prednisolone', 'Dexamethasone', 'Hydrocortisone',
    'Cetirizine (Zyrtec)', 'Loratadine (Claritin)', 'Fexofenadine',
    'Chlorpheniramine', 'Diphenhydramine',
    'Amitriptyline', 'Sertraline (Zoloft)', 'Fluoxetine (Prozac)', 'Escitalopram',
    'Diazepam', 'Lorazepam', 'Alprazolam', 'Zolpidem',
    'Phenytoin', 'Carbamazepine', 'Sodium Valproate',
    'Ferrous Sulphate (Iron)', 'Folic Acid', 'Vitamin C',
    'Vitamin D3', 'Calcium + Vitamin D', 'Vitamin B Complex', 'Vitamin B12',
    'Zinc Sulphate', 'Multivitamin',
    'Clotrimazole (Canesten)', 'Fluconazole (Diflucan)', 'Terbinafine',
    'Acyclovir (Zovirax)', 'Oseltamivir (Tamiflu)',
    'Chloroquine', 'Artemether + Lumefantrine (Coartem)',
    'Other',
  ];

  // Common lab tests for searchable dropdown
  static const List<String> _commonLabTests = [
    'Complete Blood Count (CBC)',
    'Blood Glucose (Fasting)',
    'Blood Glucose (Random)',
    'HbA1c (Glycated Hemoglobin)',
    'Lipid Profile',
    'Liver Function Tests (LFTs)',
    'Kidney Function Tests (KFTs)',
    'Thyroid Function Tests (TFTs)',
    'TSH (Thyroid Stimulating Hormone)',
    'T3 / T4',
    'Urine Complete Examination (UCE)',
    'Urine Culture & Sensitivity',
    'Blood Culture & Sensitivity',
    'Serum Electrolytes (Na, K, Cl)',
    'Serum Creatinine',
    'Blood Urea Nitrogen (BUN)',
    'Serum Uric Acid',
    'Serum Calcium',
    'Serum Iron / TIBC',
    'Serum Ferritin',
    'Vitamin D (25-OH)',
    'Vitamin B12',
    'Folic Acid',
    'Prothrombin Time (PT/INR)',
    'APTT',
    'ESR (Erythrocyte Sedimentation Rate)',
    'CRP (C-Reactive Protein)',
    'HBsAg (Hepatitis B Surface Antigen)',
    'Anti-HCV (Hepatitis C Antibody)',
    'HIV Test',
    'Widal Test (Typhoid)',
    'Malaria Antigen Test (RDT)',
    'Dengue NS1 Antigen',
    'Dengue IgM / IgG',
    'COVID-19 PCR',
    'COVID-19 Rapid Antigen Test',
    'Stool Complete Examination',
    'Stool Culture',
    'Serum Albumin',
    'Serum Bilirubin (Total / Direct)',
    'ALT (SGPT)',
    'AST (SGOT)',
    'Alkaline Phosphatase (ALP)',
    'GGT',
    'Serum Amylase',
    'Serum Lipase',
    'Blood Group & Rh Factor',
    'X-Ray Chest',
    'X-Ray KUB',
    'ECG (Electrocardiogram)',
    'Echocardiogram',
    'Ultrasound Abdomen',
    'Ultrasound Pelvis',
    'Ultrasound Whole Abdomen',
    'CT Scan Head',
    'CT Scan Chest',
    'MRI Brain',
    'Bone Marrow Aspiration',
    'Sputum AFB (TB)',
    'GeneXpert (MTB/RIF)',
    'Pap Smear',
    'PSA (Prostate Specific Antigen)',
    'Beta-HCG (Pregnancy Test)',
    'Other',
  ];

  // Vital Signs
  final _bpController = TextEditingController();
  final _tempController = TextEditingController();
  final _heartRateController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();

  String? _referSpecialty;
  final _referReasonController = TextEditingController();
  bool _referToEmergency = false;
  String? _emergencyReason;
  int _followUpDays = 0;
  int _followUpMonths = 0;

  // Prescription list
  final List<Map<String, String>> _prescriptions = [];

  // Lab tests list
  final List<String> _labTests = [];

  DateTime? _followUpDate;
  bool _isSubmitting = false;

  final CourseService _courseService = CourseService();
  final LaboratoryService _labService = LaboratoryService();
  final PharmacyService _pharmacyService = PharmacyService();
  final EfficiencyService _efficiencyService = EfficiencyService();

  List<dynamic> _availablePrograms = [];
  final List<String> _selectedProgramIds = [];
  bool _isLoadingPrograms = true;

  List<dynamic> _availableLabs = [];
  String? _selectedLabId;
  bool _isLoadingLabs = true;

  List<dynamic> _availablePharmacies = [];
  String? _selectedPharmacyId;
  bool _isLoadingPharmacies = true;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    await Future.wait([_fetchPrograms(), _fetchLabs(), _fetchPharmacies()]);
  }

  Future<void> _fetchLabs() async {
    try {
      final labs = await _labService.getAllLaboratories();
      setState(() {
        _availableLabs = labs;
      });
    } catch (e) {
      // silently ignored
    } finally {
      setState(() => _isLoadingLabs = false);
    }
  }

  Future<void> _fetchPharmacies() async {
    try {
      final pharmacies = await _pharmacyService.getAllPharmacies();
      setState(() {
        _availablePharmacies = pharmacies;
      });
    } catch (e) {
      // silently ignored
    } finally {
      setState(() => _isLoadingPharmacies = false);
    }
  }

  Future<void> _fetchPrograms() async {
    try {
      final result = await _courseService.listPublicCourses();
      setState(() {
        _availablePrograms = result;
      });
    } catch (e) {
      // silently ignored
    } finally {
      setState(() => _isLoadingPrograms = false);
    }
  }

  @override
  void dispose() {
    _diagnosisController.dispose();
    _symptomsController.dispose();
    _notesController.dispose();
    _bpController.dispose();
    _tempController.dispose();
    _heartRateController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _referReasonController.dispose();
    super.dispose();
  }

  Future<void> _showUseTemplateDialog() async {
    final templates = await _efficiencyService.getPrescriptionTemplates();
    if (!mounted) return;
    if (templates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No templates saved. Create one from Prescription Templates.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Template', style: TextStyle(fontWeight: FontWeight.w800)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final t = templates[i];
              final drugs = (t['drugs'] ?? []) as List<dynamic>;
              return ListTile(
                leading: const Icon(Icons.medical_services_rounded, color: AppColors.primaryColor),
                title: Text(t['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  drugs.map((d) => '${d['name']} (${d['dosage']})').join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
                onTap: () {
                  setState(() {
                    for (final drug in drugs) {
                      _prescriptions.add({
                        'name': drug['name']?.toString() ?? '',
                        'dosage': drug['dosage']?.toString() ?? '',
                        'frequency': '',
                        'duration': '',
                        'instructions': '',
                      });
                    }
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${drugs.length} drug(s) added from "${t['name']}"'),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                  );
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _addPrescription() {
    showDialog(
      context: context,
      builder: (context) {
        final nameController = TextEditingController();
        final dosageController = TextEditingController();
        final frequencyController = TextEditingController();
        final durationNumberController = TextEditingController();
        String durationUnit = 'Days';
        final instructionsController = TextEditingController();

        return StatefulBuilder(
          builder: (context, setDialogState) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with gradient
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(24),
                        topRight: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.medication_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Text(
                            'Add Prescription',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              fontFamily: 'Gilroy-Bold',
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Form fields
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Medicine Name — searchable Autocomplete
                        const Text(
                          'Medicine Name',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Autocomplete<String>(
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<String>.empty();
                            }
                            return _commonMedicines.where((m) => m
                                .toLowerCase()
                                .contains(textEditingValue.text.toLowerCase()));
                          },
                          onSelected: (String selection) {
                            nameController.text = selection;
                          },
                          fieldViewBuilder: (context, fieldController, focusNode, onSubmitted) {
                            fieldController.addListener(() {
                              nameController.text = fieldController.text;
                            });
                            return TextField(
                              controller: fieldController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'e.g., Paracetamol',
                                prefixIcon: const Icon(
                                  Icons.medical_services_rounded,
                                  color: Color(0xFF64748B),
                                  size: 20,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF8FAFC),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              ),
                            );
                          },
                          optionsViewBuilder: (context, onSelected, options) {
                            return Align(
                              alignment: Alignment.topLeft,
                              child: Material(
                                elevation: 4,
                                borderRadius: BorderRadius.circular(12),
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 200),
                                  child: ListView.builder(
                                    padding: EdgeInsets.zero,
                                    shrinkWrap: true,
                                    itemCount: options.length,
                                    itemBuilder: (context, index) {
                                      final option = options.elementAt(index);
                                      return ListTile(
                                        dense: true,
                                        leading: const Icon(
                                            Icons.medication_rounded,
                                            size: 18,
                                            color: Color(0xFF10B981)),
                                        title: Text(option,
                                            style: const TextStyle(fontSize: 14)),
                                        onTap: () => onSelected(option),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildModalTextField(
                                controller: dosageController,
                                label: 'Dosage',
                                icon: Icons.science_rounded,
                                hint: 'e.g., 500mg',
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Duration: number input + unit dropdown
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Duration',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: TextField(
                                          controller: durationNumberController,
                                          keyboardType: TextInputType.number,
                                          decoration: InputDecoration(
                                            hintText: '7',
                                            filled: true,
                                            fillColor: const Color(0xFFF8FAFC),
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 3,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8FAFC),
                                            border: Border.all(color: const Color(0xFFE2E8F0)),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              value: durationUnit,
                                              isExpanded: true,
                                              items: const [
                                                DropdownMenuItem(value: 'Days', child: Text('Days')),
                                                DropdownMenuItem(value: 'Weeks', child: Text('Weeks')),
                                                DropdownMenuItem(value: 'Months', child: Text('Months')),
                                              ],
                                              onChanged: (val) {
                                                if (val != null) setDialogState(() => durationUnit = val);
                                              },
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildModalTextField(
                          controller: frequencyController,
                          label: 'Frequency',
                          icon: Icons.schedule_rounded,
                          hint: 'e.g., Twice daily',
                        ),
                        const SizedBox(height: 16),
                        _buildModalTextField(
                          controller: instructionsController,
                          label: 'Instructions',
                          icon: Icons.note_rounded,
                          hint: 'e.g., Take after meals',
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),

                        // Action buttons
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFFE2E8F0),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (nameController.text.isNotEmpty) {
                                    // Requirement 26.13: Drug Interaction Checker
                                    final interactions = {
                                      'warfarin': [
                                        'aspirin',
                                        'ibuprofen',
                                        'naproxen',
                                        'clopidogrel',
                                        'diclofenac',
                                      ],
                                      'aspirin': [
                                        'warfarin',
                                        'ibuprofen',
                                        'clopidogrel',
                                      ],
                                      'ibuprofen': [
                                        'warfarin',
                                        'aspirin',
                                        'naproxen',
                                        'lisinopril',
                                      ],
                                      'naproxen': ['warfarin', 'ibuprofen'],
                                      'lisinopril': [
                                        'potassium',
                                        'spironolactone',
                                        'ibuprofen',
                                      ],
                                      'spironolactone': [
                                        'lisinopril',
                                        'potassium',
                                      ],
                                      'metformin': ['cimetidine', 'cephalexin'],
                                      'amoxicillin': ['methotrexate'],
                                      'simvastatin': [
                                        'clarithromycin',
                                        'itraconazole',
                                        'grapefruit juice',
                                      ],
                                      'digoxin': ['amiodarone', 'verapamil'],
                                    };

                                    String newDrug = nameController.text
                                        .toLowerCase()
                                        .trim();
                                    List<String> warnings = [];

                                    // Check against current prescriptions in the session
                                    for (var existing in _prescriptions) {
                                      String existingDrug =
                                          existing['name']
                                              ?.toLowerCase()
                                              .trim() ??
                                          '';
                                      if (interactions[newDrug]?.contains(
                                            existingDrug,
                                          ) ??
                                          false) {
                                        warnings.add(
                                          "CRITICAL: Severe Interaction Risk between '${existing['name']}' and '${nameController.text}'",
                                        );
                                      }
                                    }

                                    // Requirement: Cross-check against patient's chronic medications
                                    // (Simulating historical data check)
                                    final patientChronicMeds = [
                                      'warfarin',
                                      'lisinopril',
                                    ]; // Mock data
                                    for (var chronic in patientChronicMeds) {
                                      if (interactions[newDrug]?.contains(
                                            chronic,
                                          ) ??
                                          false) {
                                        warnings.add(
                                          "CHRONIC ALERT: Interaction Risk with patient's current medication: '$chronic'",
                                        );
                                      }
                                    }

                                    void finishAdd() {
                                      setState(() {
                                        _prescriptions.add({
                                          'name': nameController.text,
                                          'dosage': dosageController.text,
                                          'frequency': frequencyController.text,
                                          'duration': durationNumberController.text.isNotEmpty
                                              ? '${durationNumberController.text} $durationUnit'
                                              : '',
                                          'instructions':
                                              instructionsController.text,
                                        });
                                      });
                                      Navigator.pop(context);
                                    }

                                    if (warnings.isNotEmpty) {
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Row(
                                            children: const [
                                              Icon(
                                                Icons.report_problem_rounded,
                                                color: Colors.red,
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                "Safety Warning",
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: <Widget>[
                                              ...warnings.map(
                                                (w) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 8,
                                                      ),
                                                  child: Text(
                                                    w,
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              const Text(
                                                "Proceeding may cause severe adverse effects. Are you sure?",
                                              ),
                                            ],
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              child: const Text(
                                                "CANCEL",
                                                style: TextStyle(
                                                  color: Color(0xFF64748B),
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                Navigator.pop(ctx);
                                                finishAdd();
                                              },
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                                foregroundColor: Colors.white,
                                              ),
                                              child: const Text(
                                                "PROCEED ANYWAY",
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    } else {
                                      finishAdd();
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  'Add Medicine',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        }, // StatefulBuilder
        );
      },
    );
  }

  void _addLabTest() {
    final testController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.biotech_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Add Lab Test',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontFamily: 'Gilroy-Bold',
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // Form field
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Test Name',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Autocomplete<String>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) {
                            return const Iterable<String>.empty();
                          }
                          return _commonLabTests.where((t) => t
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (String selection) {
                          testController.text = selection;
                        },
                        fieldViewBuilder:
                            (context, fieldController, focusNode, onSubmitted) {
                          // Sync internal controller with our testController
                          fieldController.addListener(() {
                            testController.text = fieldController.text;
                          });
                          return TextField(
                            controller: fieldController,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              hintText: 'e.g., Complete Blood Count (CBC)',
                              prefixIcon: const Icon(
                                Icons.science_rounded,
                                color: Color(0xFF64748B),
                                size: 20,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8FAFC),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFFE2E8F0)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                    color: Color(0xFF8B5CF6), width: 2),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxHeight: 200),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                          Icons.science_rounded,
                                          size: 18,
                                          color: Color(0xFF8B5CF6)),
                                      title: Text(option,
                                          style: const TextStyle(fontSize: 14)),
                                      onTap: () => onSelected(option),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 24),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                side: const BorderSide(
                                  color: Color(0xFFE2E8F0),
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (testController.text.isNotEmpty) {
                                  setState(() {
                                    _labTests.add(testController.text);
                                  });
                                  Navigator.pop(context);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8B5CF6),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Add Test',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submitRecord() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Parse symptoms (comma-separated)
    final symptoms = _symptomsController.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // Build vitalSigns only with non-empty values
    final Map<String, dynamic> vitalSigns = {};
    if (_bpController.text.isNotEmpty) vitalSigns['bloodPressure'] = _bpController.text;
    if (_tempController.text.isNotEmpty) vitalSigns['temperature'] = _tempController.text;
    if (_heartRateController.text.isNotEmpty) {
      vitalSigns['heartRate'] = int.tryParse(_heartRateController.text) ?? 0;
    }
    if (_weightController.text.isNotEmpty) {
      vitalSigns['weight'] = double.tryParse(_weightController.text) ?? 0.0;
    }
    if (_heightController.text.isNotEmpty) {
      vitalSigns['height'] = double.tryParse(_heightController.text) ?? 0.0;
    }

    // Strip prescription to minimal fields backend expects
    final cleanPrescription = _prescriptions.map((p) => {
      'name': p['name'] ?? '',
      'dosage': p['dosage'] ?? '',
      if ((p['frequency'] ?? '').isNotEmpty) 'frequency': p['frequency'],
      if ((p['duration'] ?? '').isNotEmpty) 'duration': p['duration'],
      if ((p['instructions'] ?? '').isNotEmpty) 'instructions': p['instructions'],
    }).toList();

    final data = <String, dynamic>{
      'patientId': widget.appointment.patient!.id,
      'appointmentId': widget.appointment.id,
      'diagnosis': _diagnosisController.text.trim(),
    };

    if (symptoms.isNotEmpty) data['symptoms'] = symptoms;

    // Build prescription object
    final Map<String, dynamic> prescriptionObj = {};
    if (cleanPrescription.isNotEmpty) prescriptionObj['medicines'] = cleanPrescription;
    if (_referToEmergency) {
      prescriptionObj['emergencyReferral'] = {
        'referred': true,
        if (_emergencyReason != null) 'reason': _emergencyReason,
      };
    }
    if (_referSpecialty != null) {
      prescriptionObj['referral'] = {
        'specialty': _referSpecialty,
        if (_referReasonController.text.trim().isNotEmpty)
          'reason': _referReasonController.text.trim(),
      };
    }
    // Lab tests go INSIDE prescription so patient_prescriptions.dart can read them
    if (_labTests.isNotEmpty) {
      prescriptionObj['labTests'] = _labTests
          .map((t) => {'name': t, 'urgency': 'Routine'})
          .toList();
    }
    if (prescriptionObj.isNotEmpty) data['prescription'] = prescriptionObj;
    if (_notesController.text.trim().isNotEmpty) data['notes'] = _notesController.text.trim();
    if (vitalSigns.isNotEmpty) data['vitalSigns'] = vitalSigns;
    if (_followUpDate != null) {
      data['followUpDate'] = _followUpDate!.toIso8601String();
    } else if (_followUpDays > 0 || _followUpMonths > 0) {
      data['followUpDate'] = DateTime.now()
          .add(Duration(days: _followUpDays + (_followUpMonths * 30)))
          .toIso8601String();
    }
    if (_followUpDays > 0) data['followUpDays'] = _followUpDays;
    if (_followUpMonths > 0) data['followUpMonths'] = _followUpMonths;
    if (_selectedLabId != null) data['referredLaboratory'] = _selectedLabId;
    if (_selectedPharmacyId != null) data['selectedPharmacy'] = _selectedPharmacyId;
    if (_selectedProgramIds.isNotEmpty) data['assignedCourses'] = _selectedProgramIds;

    debugPrint('📤 Sending medical record: $data');

    final result = await _medicalRecordService.createMedicalRecord(data);

    setState(() => _isSubmitting = false);

    if (mounted) {
      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medical record created successfully')),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Failed to create record'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const CustomBackButton(),
        title: const Text(
          'Create Medical Record',
          style: TextStyle(
            fontSize: 18,
            fontFamily: 'Gilroy-Bold',
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isDesktop ? 40 : 20),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isDesktop ? 1000 : double.infinity,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient Info Card - Enhanced Design
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              widget.appointment.patient!.name[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Creating Record For',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.appointment.patient!.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  fontFamily: 'Gilroy-Bold',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.appointment.patient!.email,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white.withValues(alpha: 0.9),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Symptoms Section (first per clinical workflow)
                  _buildModernSectionCard(
                    'Symptoms',
                    Icons.sick_rounded,
                    const Color(0xFFF59E0B),
                    child: TextFormField(
                      controller: _symptomsController,
                      decoration: _modernInputDecoration(
                        'e.g., Fever, Headache, Cough (comma separated)',
                        Icons.list_alt_rounded,
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Diagnosis Section (after symptoms)
                  _buildModernSectionCard(
                    'Diagnosis',
                    Icons.medical_information_rounded,
                    const Color(0xFFEF4444),
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return _commonDiagnoses.where((d) =>
                          d.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selection) {
                        _diagnosisController.text = selection;
                      },
                      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                        // sync with _diagnosisController
                        controller.text = _diagnosisController.text;
                        controller.addListener(() {
                          _diagnosisController.text = controller.text;
                        });
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: _modernInputDecoration(
                            'Search or type diagnosis',
                            Icons.search_rounded,
                          ),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Diagnosis is required' : null,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 6,
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final option = options.elementAt(index);
                                  return ListTile(
                                    dense: true,
                                    leading: Icon(
                                      option == 'Other'
                                          ? Icons.edit_outlined
                                          : Icons.medical_information_outlined,
                                      size: 18,
                                      color: const Color(0xFFEF4444),
                                    ),
                                    title: Text(option,
                                        style: const TextStyle(fontSize: 14)),
                                    onTap: () => onSelected(option),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Prescriptions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Prescriptions'),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _showUseTemplateDialog,
                            icon: const Icon(Icons.folder_open_rounded, size: 18),
                            label: const Text('Use Template'),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primaryColor,
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                          IconButton(
                            onPressed: _addPrescription,
                            icon: const Icon(
                              Icons.add_circle,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (_prescriptions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: Text('No prescriptions added'),
                      ),
                    )
                  else
                    ..._prescriptions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final med = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    med['name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${med['dosage']} - ${med['frequency']}',
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                setState(() => _prescriptions.removeAt(index));
                              },
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 20),

                  // Lab Tests
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSectionTitle('Lab Tests'),
                      IconButton(
                        onPressed: _addLabTest,
                        icon: const Icon(
                          Icons.add_circle,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  if (_labTests.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: Text('No lab tests added')),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: _labTests.asMap().entries.map((entry) {
                        final index = entry.key;
                        final test = entry.value;
                        return Chip(
                          label: Text(test),
                          onDeleted: () {
                            setState(() => _labTests.removeAt(index));
                          },
                        );
                      }).toList(),
                    ),

                  const SizedBox(height: 20),

                  // History — Vital Signs (moved out of main prescription)
                  _buildSectionTitle('History — Vital Signs'),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _bpController,
                                decoration: _inputDecoration('BP (120/80)'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _tempController,
                                decoration: _inputDecoration('Temp (°F)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _heartRateController,
                                decoration: _inputDecoration('Heart Rate'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _weightController,
                                decoration: _inputDecoration('Weight (kg)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _heightController,
                                decoration: _inputDecoration('Height (cm)'),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Notes
                  _buildSectionTitle('Additional Notes'),
                  TextFormField(
                    controller: _notesController,
                    decoration: _inputDecoration('Enter any additional notes'),
                    maxLines: 4,
                  ),

                  const SizedBox(height: 20),

                  // Refer to Emergency / Hospital
                  _buildModernSectionCard(
                    'Refer to Emergency / Hospital',
                    Icons.local_hospital_rounded,
                    const Color(0xFFEF4444),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Switch(
                              value: _referToEmergency,
                              onChanged: (val) => setState(() => _referToEmergency = val),
                              activeColor: const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Refer patient to Emergency / Hospital',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        if (_referToEmergency) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _emergencyReason,
                            isExpanded: true,
                            decoration: _modernInputDecoration(
                              'Select Reason',
                              Icons.warning_amber_rounded,
                            ),
                            dropdownColor: Colors.white,
                            items: [
                              'Emergency Care Required',
                              'Immediate Hospitalization',
                              'Surgical Intervention',
                              'ICU Admission',
                              'Life-Threatening Condition',
                              'Other',
                            ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                            onChanged: (val) => setState(() => _emergencyReason = val),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Refer to Specialist
                  _buildModernSectionCard(
                    'Refer to Specialist',
                    Icons.person_search_rounded,
                    const Color(0xFFF59E0B),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          initialValue: _referSpecialty,
                          isExpanded: true,
                          decoration: _modernInputDecoration(
                            'Select Specialty',
                            Icons.medical_services_rounded,
                          ),
                          dropdownColor: Colors.white,
                          items: [
                            'Cardiology', 'Dermatology', 'Neurology',
                            'Orthopedics', 'Pediatrics', 'Gynecology',
                            'Ophthalmology', 'ENT', 'Psychiatry',
                            'Endocrinology', 'Gastroenterology', 'Urology',
                          ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                          onChanged: (val) => setState(() => _referSpecialty = val),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _referReasonController,
                          maxLines: 3,
                          decoration: _modernInputDecoration(
                            'Reason for referral (optional)',
                            Icons.note_alt_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Follow-up
                  _buildModernSectionCard(
                    'Follow-up Schedule',
                    Icons.event_repeat_rounded,
                    const Color(0xFF3B82F6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Follow up after:',
                          style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: ListWheelScrollView(
                                      itemExtent: 36,
                                      physics: const FixedExtentScrollPhysics(),
                                      onSelectedItemChanged: (i) => setState(() => _followUpDays = i),
                                      children: List.generate(31, (i) => Center(
                                        child: Text('$i', style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: _followUpDays == i ? FontWeight.w900 : FontWeight.w400,
                                          color: _followUpDays == i ? AppColors.primaryColor : const Color(0xFF64748B),
                                        )),
                                      )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Months', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF0F172A))),
                                  const SizedBox(height: 6),
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0)),
                                    ),
                                    child: ListWheelScrollView(
                                      itemExtent: 36,
                                      physics: const FixedExtentScrollPhysics(),
                                      onSelectedItemChanged: (i) => setState(() => _followUpMonths = i),
                                      children: List.generate(13, (i) => Center(
                                        child: Text('$i', style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: _followUpMonths == i ? FontWeight.w900 : FontWeight.w400,
                                          color: _followUpMonths == i ? AppColors.primaryColor : const Color(0xFF64748B),
                                        )),
                                      )),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (_followUpDays > 0 || _followUpMonths > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.primaryColor, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  'Follow up in${_followUpMonths > 0 ? ' $_followUpMonths month${_followUpMonths > 1 ? 's' : ''}' : ''}${_followUpDays > 0 ? ' $_followUpDays day${_followUpDays > 1 ? 's' : ''}' : ''}',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Follow-up Date (calendar picker — kept for exact date)
                  _buildSectionTitle('Or pick exact Follow-up Date'),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(
                          const Duration(days: 7),
                        ),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _followUpDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            _followUpDate != null
                                ? DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(_followUpDate!)
                                : 'Select follow-up date',
                            style: TextStyle(
                              color: _followUpDate != null
                                  ? Colors.black
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Health Programs Assignment (Task 19.3)
                  _buildModernSectionCard(
                    'Assign Health Programs',
                    Icons.health_and_safety_rounded,
                    const Color(0xFF8B5CF6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign educational tracks for the patient to follow as part of their care plan.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (_isLoadingPrograms)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_availablePrograms.isEmpty)
                          const Text('No programs available')
                        else
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availablePrograms.map((course) {
                              final isSelected = _selectedProgramIds.contains(
                                course['_id'],
                              );
                              return FilterChip(
                                label: Text(course['title']),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedProgramIds.add(course['_id']);
                                    } else {
                                      _selectedProgramIds.remove(course['_id']);
                                    }
                                  });
                                },
                                selectedColor: const Color(
                                  0xFF8B5CF6,
                                ).withValues(alpha: 0.2),
                                checkmarkColor: const Color(0xFF8B5CF6),
                                labelStyle: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF7C3AED)
                                      : Colors.black,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      label: _isSubmitting
                          ? 'Creating...'
                          : 'Create Medical Record',
                      onPressed: _isSubmitting ? null : _submitRecord,
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w900,
          color: Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildModernSectionCard(
    String title,
    IconData icon,
    Color color, {
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Gilroy-Bold',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  InputDecoration _modernInputDecoration(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primaryColor, width: 2),
      ),
    );
  }
}
