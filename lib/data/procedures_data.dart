// Common clinic procedures with a default price (PKR) — searchable list for
// the reception "Add Procedure" screen. Prices are starting defaults only;
// the receptionist can always edit the price after picking one.

class ProcedureItem {
  final String name;
  final double defaultPrice;

  const ProcedureItem({required this.name, required this.defaultPrice});
}

const List<ProcedureItem> kCommonProcedures = [
  ProcedureItem(name: 'Consultation', defaultPrice: 1000),
  ProcedureItem(name: 'Follow-up Consultation', defaultPrice: 500),
  ProcedureItem(name: 'Dressing (Small)', defaultPrice: 300),
  ProcedureItem(name: 'Dressing (Large)', defaultPrice: 600),
  ProcedureItem(name: 'Injection (IM)', defaultPrice: 200),
  ProcedureItem(name: 'Injection (IV)', defaultPrice: 300),
  ProcedureItem(name: 'IV Cannulation', defaultPrice: 400),
  ProcedureItem(name: 'IV Infusion / Drip', defaultPrice: 800),
  ProcedureItem(name: 'Minor Suture', defaultPrice: 1500),
  ProcedureItem(name: 'Suture Removal', defaultPrice: 300),
  ProcedureItem(name: 'Wound Cleaning', defaultPrice: 300),
  ProcedureItem(name: 'Abscess Incision & Drainage', defaultPrice: 2000),
  ProcedureItem(name: 'Nebulization', defaultPrice: 400),
  ProcedureItem(name: 'Ear Syringing / Wax Removal', defaultPrice: 800),
  ProcedureItem(name: 'Foreign Body Removal', defaultPrice: 1000),
  ProcedureItem(name: 'Blood Pressure Check', defaultPrice: 100),
  ProcedureItem(name: 'Blood Sugar Test (Glucometer)', defaultPrice: 150),
  ProcedureItem(name: 'ECG', defaultPrice: 800),
  ProcedureItem(name: 'X-Ray', defaultPrice: 1200),
  ProcedureItem(name: 'Ultrasound', defaultPrice: 2000),
  ProcedureItem(name: 'Nail Removal (Partial)', defaultPrice: 1500),
  ProcedureItem(name: 'Nail Removal (Complete)', defaultPrice: 2500),
  ProcedureItem(name: 'Skin Biopsy', defaultPrice: 2500),
  ProcedureItem(name: 'Cautery / Wart Removal', defaultPrice: 1500),
  ProcedureItem(name: 'Catheterization (Urinary)', defaultPrice: 1500),
  ProcedureItem(name: 'Cast / Splint Application', defaultPrice: 2000),
  ProcedureItem(name: 'Cast Removal', defaultPrice: 500),
  ProcedureItem(name: 'Vaccination', defaultPrice: 500),
  ProcedureItem(name: 'Circumcision', defaultPrice: 8000),
  ProcedureItem(name: 'Pap Smear', defaultPrice: 1500),
  ProcedureItem(name: 'Physiotherapy Session', defaultPrice: 1500),
  ProcedureItem(name: 'Minor Surgery', defaultPrice: 5000),
  ProcedureItem(name: 'Oxygen Therapy', defaultPrice: 500),
];

List<ProcedureItem> searchProcedures(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return kCommonProcedures;
  return kCommonProcedures.where((p) => p.name.toLowerCase().contains(q)).toList();
}
