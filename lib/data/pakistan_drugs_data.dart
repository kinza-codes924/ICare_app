// Pakistani Drug Database — Generic → Brand → Form/Strength
// Based on drugs commonly available in Pakistan (DRAP registered)

class DrugBrand {
  final String brandName;
  final String company;
  final List<String> forms;
  final List<String> strengths;

  const DrugBrand({
    required this.brandName,
    required this.company,
    required this.forms,
    required this.strengths,
  });
}

class DrugFormula {
  final String genericName;
  final String category;
  final List<DrugBrand> brands;

  const DrugFormula({
    required this.genericName,
    required this.category,
    required this.brands,
  });
}

const List<DrugFormula> kPakistanDrugs = [
  DrugFormula(
    genericName: 'Paracetamol',
    category: 'Analgesic / Antipyretic',
    brands: [
      DrugBrand(brandName: 'Panadol', company: 'GSK', forms: ['Tablet', 'Syrup', 'Drops', 'Suppository'], strengths: ['500mg', '1g', '120mg/5ml', '80mg']),
      DrugBrand(brandName: 'Panadol Extra', company: 'GSK', forms: ['Tablet'], strengths: ['500mg+65mg (caffeine)']),
      DrugBrand(brandName: 'Calpol', company: 'GSK', forms: ['Syrup', 'Suspension'], strengths: ['120mg/5ml', '250mg/5ml']),
      DrugBrand(brandName: 'Acetamol', company: 'Legacy', forms: ['Tablet', 'Syrup'], strengths: ['500mg', '120mg/5ml']),
      DrugBrand(brandName: 'Febricet', company: 'Scotmann', forms: ['Tablet', 'Syrup'], strengths: ['500mg', '120mg/5ml']),
      DrugBrand(brandName: 'Disprin', company: 'Reckitt', forms: ['Effervescent Tablet'], strengths: ['500mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Amoxicillin',
    category: 'Antibiotic',
    brands: [
      DrugBrand(brandName: 'Amoxil', company: 'GSK', forms: ['Capsule', 'Suspension', 'Injection'], strengths: ['250mg', '500mg', '125mg/5ml', '250mg/5ml', '500mg/vial']),
      DrugBrand(brandName: 'Ospamox', company: 'Sandoz', forms: ['Capsule', 'Suspension'], strengths: ['250mg', '500mg', '125mg/5ml']),
      DrugBrand(brandName: 'Moxlin', company: 'Getz', forms: ['Capsule', 'Suspension'], strengths: ['250mg', '500mg', '125mg/5ml']),
      DrugBrand(brandName: 'Amoxin', company: 'ICI', forms: ['Capsule', 'Suspension'], strengths: ['250mg', '500mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Amoxicillin + Clavulanic Acid',
    category: 'Antibiotic (Broad Spectrum)',
    brands: [
      DrugBrand(brandName: 'Augmentin', company: 'GSK', forms: ['Tablet', 'Suspension', 'Injection'], strengths: ['375mg', '625mg', '1g', '156.25mg/5ml', '228.5mg/5ml']),
      DrugBrand(brandName: 'Amoclan', company: 'Getz', forms: ['Tablet', 'Suspension'], strengths: ['375mg', '625mg', '156.25mg/5ml']),
      DrugBrand(brandName: 'Clavam', company: 'Cipla', forms: ['Tablet'], strengths: ['625mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Azithromycin',
    category: 'Antibiotic (Macrolide)',
    brands: [
      DrugBrand(brandName: 'Azifast', company: 'Getz', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg', '200mg/5ml']),
      DrugBrand(brandName: 'Zithromax', company: 'Pfizer', forms: ['Tablet', 'Suspension', 'Injection'], strengths: ['250mg', '500mg', '200mg/5ml', '500mg/vial']),
      DrugBrand(brandName: 'Azibact', company: 'Scilife', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg']),
      DrugBrand(brandName: 'Azithral', company: 'Alembic', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg', '200mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Ciprofloxacin',
    category: 'Antibiotic (Fluoroquinolone)',
    brands: [
      DrugBrand(brandName: 'Cipro', company: 'Bayer', forms: ['Tablet', 'Suspension', 'Injection', 'Eye Drops'], strengths: ['250mg', '500mg', '750mg', '250mg/5ml', '200mg/100ml']),
      DrugBrand(brandName: 'Ciprox', company: 'Getz', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg', '750mg']),
      DrugBrand(brandName: 'Bactiflox', company: 'ICI', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg']),
      DrugBrand(brandName: 'Ciplox', company: 'Cipla', forms: ['Tablet', 'Eye Drops'], strengths: ['250mg', '500mg', '0.3%']),
    ],
  ),
  DrugFormula(
    genericName: 'Metformin',
    category: 'Antidiabetic',
    brands: [
      DrugBrand(brandName: 'Glucophage', company: 'Merck', forms: ['Tablet', 'XR Tablet'], strengths: ['500mg', '850mg', '1000mg']),
      DrugBrand(brandName: 'Oformin', company: 'Getz', forms: ['Tablet'], strengths: ['500mg', '850mg', '1000mg']),
      DrugBrand(brandName: 'Formin', company: 'ICI', forms: ['Tablet'], strengths: ['500mg', '850mg']),
      DrugBrand(brandName: 'Diabex', company: 'Atco', forms: ['Tablet'], strengths: ['500mg', '850mg', '1000mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Amlodipine',
    category: 'Antihypertensive (Calcium Channel Blocker)',
    brands: [
      DrugBrand(brandName: 'Norvasc', company: 'Pfizer', forms: ['Tablet'], strengths: ['5mg', '10mg']),
      DrugBrand(brandName: 'Amlovas', company: 'Getz', forms: ['Tablet'], strengths: ['5mg', '10mg']),
      DrugBrand(brandName: 'Amtas', company: 'Getz', forms: ['Tablet'], strengths: ['5mg', '10mg']),
      DrugBrand(brandName: 'Amlopin', company: 'Atco', forms: ['Tablet'], strengths: ['5mg', '10mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Atorvastatin',
    category: 'Antihyperlipidemic (Statin)',
    brands: [
      DrugBrand(brandName: 'Lipitor', company: 'Pfizer', forms: ['Tablet'], strengths: ['10mg', '20mg', '40mg', '80mg']),
      DrugBrand(brandName: 'Atorva', company: 'Scotmann', forms: ['Tablet'], strengths: ['10mg', '20mg', '40mg']),
      DrugBrand(brandName: 'Atova', company: 'Getz', forms: ['Tablet'], strengths: ['10mg', '20mg', '40mg', '80mg']),
      DrugBrand(brandName: 'Statvast', company: 'AGP', forms: ['Tablet'], strengths: ['10mg', '20mg', '40mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Omeprazole',
    category: 'Proton Pump Inhibitor',
    brands: [
      DrugBrand(brandName: 'Risek', company: 'Getz', forms: ['Capsule', 'Injection'], strengths: ['20mg', '40mg', '40mg/vial']),
      DrugBrand(brandName: 'Lokit', company: 'AGP', forms: ['Capsule'], strengths: ['20mg', '40mg']),
      DrugBrand(brandName: 'Omix', company: 'ICI', forms: ['Capsule'], strengths: ['20mg']),
      DrugBrand(brandName: 'Gastrol', company: 'Sami', forms: ['Capsule'], strengths: ['20mg', '40mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Pantoprazole',
    category: 'Proton Pump Inhibitor',
    brands: [
      DrugBrand(brandName: 'Controloc', company: 'Takeda', forms: ['Tablet', 'Injection'], strengths: ['20mg', '40mg', '40mg/vial']),
      DrugBrand(brandName: 'Pantoloc', company: 'Nycomed', forms: ['Tablet'], strengths: ['20mg', '40mg']),
      DrugBrand(brandName: 'Pantop', company: 'Getz', forms: ['Tablet'], strengths: ['20mg', '40mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Metoprolol',
    category: 'Beta Blocker',
    brands: [
      DrugBrand(brandName: 'Betaloc', company: 'AstraZeneca', forms: ['Tablet', 'Injection'], strengths: ['25mg', '50mg', '100mg', '5mg/5ml']),
      DrugBrand(brandName: 'Toprol', company: 'AstraZeneca', forms: ['XL Tablet'], strengths: ['25mg', '50mg', '100mg', '200mg']),
      DrugBrand(brandName: 'Metropol', company: 'Getz', forms: ['Tablet'], strengths: ['25mg', '50mg', '100mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Losartan',
    category: 'Antihypertensive (ARB)',
    brands: [
      DrugBrand(brandName: 'Cozaar', company: 'MSD', forms: ['Tablet'], strengths: ['25mg', '50mg', '100mg']),
      DrugBrand(brandName: 'Losacar', company: 'Atco', forms: ['Tablet'], strengths: ['25mg', '50mg', '100mg']),
      DrugBrand(brandName: 'Losartan-K', company: 'Getz', forms: ['Tablet'], strengths: ['50mg', '100mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Aspirin',
    category: 'Antiplatelet / Analgesic',
    brands: [
      DrugBrand(brandName: 'Aspirin Cardio', company: 'Bayer', forms: ['Enteric Coated Tablet'], strengths: ['75mg', '100mg', '150mg', '300mg']),
      DrugBrand(brandName: 'Ecotrin', company: 'GSK', forms: ['Enteric Coated Tablet'], strengths: ['75mg', '150mg', '300mg']),
      DrugBrand(brandName: 'Disprin', company: 'Reckitt', forms: ['Effervescent Tablet'], strengths: ['300mg', '600mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Clopidogrel',
    category: 'Antiplatelet',
    brands: [
      DrugBrand(brandName: 'Plavix', company: 'Sanofi', forms: ['Tablet'], strengths: ['75mg', '300mg']),
      DrugBrand(brandName: 'Clovas', company: 'Getz', forms: ['Tablet'], strengths: ['75mg']),
      DrugBrand(brandName: 'Clopid', company: 'Atco', forms: ['Tablet'], strengths: ['75mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Prednisolone',
    category: 'Corticosteroid',
    brands: [
      DrugBrand(brandName: 'Pred-Forte', company: 'Allergan', forms: ['Tablet', 'Syrup', 'Eye Drops'], strengths: ['5mg', '25mg', '5mg/5ml', '1%']),
      DrugBrand(brandName: 'Hostacortin', company: 'Sanofi', forms: ['Tablet'], strengths: ['5mg', '10mg', '25mg', '50mg']),
      DrugBrand(brandName: 'Deltasone', company: 'Pfizer', forms: ['Tablet'], strengths: ['5mg', '10mg', '20mg', '50mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Dexamethasone',
    category: 'Corticosteroid',
    brands: [
      DrugBrand(brandName: 'Decadron', company: 'Organon', forms: ['Tablet', 'Injection'], strengths: ['0.5mg', '4mg', '8mg/2ml', '4mg/ml']),
      DrugBrand(brandName: 'Dexol', company: 'Getz', forms: ['Tablet', 'Injection'], strengths: ['0.5mg', '4mg', '8mg/2ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Salbutamol',
    category: 'Bronchodilator',
    brands: [
      DrugBrand(brandName: 'Ventolin', company: 'GSK', forms: ['Inhaler', 'Syrup', 'Nebulizer', 'Tablet'], strengths: ['100mcg/dose', '2mg/5ml', '2.5mg/2.5ml', '2mg', '4mg']),
      DrugBrand(brandName: 'Salamol', company: 'IVAX', forms: ['Inhaler', 'Syrup'], strengths: ['100mcg/dose', '2mg/5ml']),
      DrugBrand(brandName: 'Asthalin', company: 'Cipla', forms: ['Inhaler', 'Syrup'], strengths: ['100mcg/dose', '2mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Cetirizine',
    category: 'Antihistamine',
    brands: [
      DrugBrand(brandName: 'Zyrtec', company: 'UCB', forms: ['Tablet', 'Syrup'], strengths: ['10mg', '5mg/5ml']),
      DrugBrand(brandName: 'Zirtec', company: 'Getz', forms: ['Tablet', 'Syrup'], strengths: ['10mg', '5mg/5ml']),
      DrugBrand(brandName: 'Cetrin', company: 'ICI', forms: ['Tablet', 'Syrup'], strengths: ['10mg', '5mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Levothyroxine',
    category: 'Thyroid Hormone',
    brands: [
      DrugBrand(brandName: 'Eltroxin', company: 'GSK', forms: ['Tablet'], strengths: ['25mcg', '50mcg', '100mcg']),
      DrugBrand(brandName: 'Euthyrox', company: 'Merck', forms: ['Tablet'], strengths: ['25mcg', '50mcg', '75mcg', '100mcg', '125mcg', '150mcg', '200mcg']),
      DrugBrand(brandName: 'Synthroid', company: 'Abbott', forms: ['Tablet'], strengths: ['25mcg', '50mcg', '100mcg', '125mcg', '150mcg']),
    ],
  ),
  DrugFormula(
    genericName: 'Glibenclamide',
    category: 'Antidiabetic (Sulfonylurea)',
    brands: [
      DrugBrand(brandName: 'Euglucon', company: 'Sanofi', forms: ['Tablet'], strengths: ['2.5mg', '5mg']),
      DrugBrand(brandName: 'Daonil', company: 'Sanofi', forms: ['Tablet'], strengths: ['2.5mg', '5mg']),
      DrugBrand(brandName: 'Glibenclamide-Getz', company: 'Getz', forms: ['Tablet'], strengths: ['5mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Lisinopril',
    category: 'Antihypertensive (ACE Inhibitor)',
    brands: [
      DrugBrand(brandName: 'Zestril', company: 'AstraZeneca', forms: ['Tablet'], strengths: ['5mg', '10mg', '20mg']),
      DrugBrand(brandName: 'Prinivil', company: 'MSD', forms: ['Tablet'], strengths: ['5mg', '10mg', '20mg']),
      DrugBrand(brandName: 'Lisipril', company: 'Getz', forms: ['Tablet'], strengths: ['5mg', '10mg', '20mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Cefixime',
    category: 'Antibiotic (Cephalosporin)',
    brands: [
      DrugBrand(brandName: 'Suprax', company: 'Wyeth', forms: ['Tablet', 'Suspension'], strengths: ['100mg', '200mg', '400mg', '100mg/5ml']),
      DrugBrand(brandName: 'Hifen', company: 'Getz', forms: ['Tablet', 'Suspension'], strengths: ['100mg', '200mg', '400mg', '100mg/5ml']),
      DrugBrand(brandName: 'Cefix', company: 'ICI', forms: ['Tablet', 'Suspension'], strengths: ['200mg', '400mg', '100mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Cefoperazone',
    category: 'Antibiotic (Cephalosporin)',
    brands: [
      DrugBrand(brandName: 'Cefobid', company: 'Pfizer', forms: ['Injection'], strengths: ['1g/vial', '2g/vial']),
      DrugBrand(brandName: 'Cefzon', company: 'Getz', forms: ['Injection'], strengths: ['1g/vial', '2g/vial']),
      DrugBrand(brandName: 'Magnazone', company: 'Scilife', forms: ['Injection'], strengths: ['1g/vial', '2g/vial']),
    ],
  ),
  DrugFormula(
    genericName: 'Dydrogesterone',
    category: 'Progestogen',
    brands: [
      DrugBrand(brandName: 'Duphaston', company: 'Abbott', forms: ['Tablet'], strengths: ['10mg']),
      DrugBrand(brandName: 'Dydro', company: 'Atco', forms: ['Tablet'], strengths: ['10mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Metronidazole',
    category: 'Antiprotozoal / Antibiotic',
    brands: [
      DrugBrand(brandName: 'Flagyl', company: 'Sanofi', forms: ['Tablet', 'Suspension', 'Injection', 'Suppository'], strengths: ['200mg', '400mg', '500mg', '200mg/5ml', '500mg/100ml']),
      DrugBrand(brandName: 'Metrozine', company: 'ICI', forms: ['Tablet', 'Suspension'], strengths: ['200mg', '400mg', '200mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Ibuprofen',
    category: 'NSAID',
    brands: [
      DrugBrand(brandName: 'Brufen', company: 'Abbott', forms: ['Tablet', 'Syrup', 'Gel'], strengths: ['200mg', '400mg', '600mg', '100mg/5ml', '5%']),
      DrugBrand(brandName: 'Nurofen', company: 'Reckitt', forms: ['Tablet', 'Suspension'], strengths: ['200mg', '400mg', '100mg/5ml']),
      DrugBrand(brandName: 'Febrifen', company: 'Scotmann', forms: ['Tablet', 'Suspension'], strengths: ['200mg', '400mg', '100mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Diclofenac',
    category: 'NSAID',
    brands: [
      DrugBrand(brandName: 'Voltaren', company: 'Novartis', forms: ['Tablet', 'Injection', 'Gel', 'Suppository'], strengths: ['25mg', '50mg', '75mg', '75mg/3ml', '1%']),
      DrugBrand(brandName: 'Dicloran', company: 'Getz', forms: ['Tablet', 'Injection'], strengths: ['50mg', '75mg', '75mg/3ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Tramadol',
    category: 'Opioid Analgesic',
    brands: [
      DrugBrand(brandName: 'Tramal', company: 'Grunenthal', forms: ['Capsule', 'Injection', 'Drops'], strengths: ['50mg', '100mg', '50mg/ml', '100mg/2ml']),
      DrugBrand(brandName: 'Ultram', company: 'Janssen', forms: ['Tablet', 'Injection'], strengths: ['50mg', '100mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Ondansetron',
    category: 'Antiemetic',
    brands: [
      DrugBrand(brandName: 'Zofran', company: 'GSK', forms: ['Tablet', 'Injection', 'Syrup'], strengths: ['4mg', '8mg', '2mg/ml', '4mg/5ml']),
      DrugBrand(brandName: 'Emeset', company: 'Cipla', forms: ['Tablet', 'Injection'], strengths: ['4mg', '8mg', '2mg/ml']),
      DrugBrand(brandName: 'Emitron', company: 'Getz', forms: ['Tablet', 'Injection'], strengths: ['4mg', '8mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Domperidone',
    category: 'Prokinetic / Antiemetic',
    brands: [
      DrugBrand(brandName: 'Motilium', company: 'Janssen', forms: ['Tablet', 'Suspension'], strengths: ['10mg', '5mg/5ml']),
      DrugBrand(brandName: 'Motinorm', company: 'Getz', forms: ['Tablet', 'Suspension'], strengths: ['10mg', '5mg/5ml']),
      DrugBrand(brandName: 'Domperi', company: 'Reckitt', forms: ['Tablet', 'Suspension'], strengths: ['10mg', '5mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Ranitidine',
    category: 'H2 Blocker',
    brands: [
      DrugBrand(brandName: 'Zantac', company: 'GSK', forms: ['Tablet', 'Syrup', 'Injection'], strengths: ['150mg', '300mg', '75mg/5ml', '50mg/2ml']),
      DrugBrand(brandName: 'Aciloc', company: 'Cipla', forms: ['Tablet', 'Syrup'], strengths: ['150mg', '300mg', '75mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Hydroxychloroquine',
    category: 'Antimalarial / DMARD',
    brands: [
      DrugBrand(brandName: 'Plaquenil', company: 'Sanofi', forms: ['Tablet'], strengths: ['200mg']),
      DrugBrand(brandName: 'Hydroxin', company: 'AGP', forms: ['Tablet'], strengths: ['200mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Warfarin',
    category: 'Anticoagulant',
    brands: [
      DrugBrand(brandName: 'Coumadin', company: 'BMS', forms: ['Tablet'], strengths: ['1mg', '2mg', '5mg']),
      DrugBrand(brandName: 'Warf', company: 'Cipla', forms: ['Tablet'], strengths: ['1mg', '2mg', '5mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Furosemide',
    category: 'Loop Diuretic',
    brands: [
      DrugBrand(brandName: 'Lasix', company: 'Sanofi', forms: ['Tablet', 'Injection'], strengths: ['20mg', '40mg', '80mg', '10mg/ml']),
      DrugBrand(brandName: 'Frusin', company: 'Getz', forms: ['Tablet', 'Injection'], strengths: ['40mg', '80mg', '10mg/ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Spironolactone',
    category: 'Potassium-Sparing Diuretic',
    brands: [
      DrugBrand(brandName: 'Aldactone', company: 'Pfizer', forms: ['Tablet'], strengths: ['25mg', '50mg', '100mg']),
      DrugBrand(brandName: 'Spiractin', company: 'Atco', forms: ['Tablet'], strengths: ['25mg', '50mg', '100mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Clarithromycin',
    category: 'Antibiotic (Macrolide)',
    brands: [
      DrugBrand(brandName: 'Klacid', company: 'Abbott', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg', '125mg/5ml', '250mg/5ml']),
      DrugBrand(brandName: 'Biaxin', company: 'Abbott', forms: ['Tablet', 'XL Tablet'], strengths: ['250mg', '500mg']),
      DrugBrand(brandName: 'Clarex', company: 'Getz', forms: ['Tablet', 'Suspension'], strengths: ['250mg', '500mg', '125mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Doxycycline',
    category: 'Antibiotic (Tetracycline)',
    brands: [
      DrugBrand(brandName: 'Vibramycin', company: 'Pfizer', forms: ['Capsule', 'Tablet', 'Suspension'], strengths: ['100mg', '50mg/5ml']),
      DrugBrand(brandName: 'Doxin', company: 'Getz', forms: ['Capsule'], strengths: ['100mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Phenytoin',
    category: 'Anticonvulsant',
    brands: [
      DrugBrand(brandName: 'Dilantin', company: 'Pfizer', forms: ['Capsule', 'Suspension', 'Injection'], strengths: ['100mg', '125mg/5ml', '50mg/ml']),
      DrugBrand(brandName: 'Epanutin', company: 'Pfizer', forms: ['Capsule', 'Suspension'], strengths: ['100mg', '125mg/5ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Carbamazepine',
    category: 'Anticonvulsant',
    brands: [
      DrugBrand(brandName: 'Tegretol', company: 'Novartis', forms: ['Tablet', 'CR Tablet', 'Suspension'], strengths: ['100mg', '200mg', '400mg', '100mg/5ml']),
      DrugBrand(brandName: 'Carbatrol', company: 'Shire', forms: ['Extended Release Capsule'], strengths: ['100mg', '200mg', '300mg']),
    ],
  ),
  DrugFormula(
    genericName: 'Insulin (Regular)',
    category: 'Antidiabetic (Insulin)',
    brands: [
      DrugBrand(brandName: 'Actrapid', company: 'Novo Nordisk', forms: ['Injection', 'Vial', 'Pen'], strengths: ['100IU/ml']),
      DrugBrand(brandName: 'Humulin R', company: 'Lilly', forms: ['Injection', 'Vial'], strengths: ['100IU/ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Insulin (Isophane/NPH)',
    category: 'Antidiabetic (Insulin)',
    brands: [
      DrugBrand(brandName: 'Insulatard', company: 'Novo Nordisk', forms: ['Injection', 'Vial', 'Pen'], strengths: ['100IU/ml']),
      DrugBrand(brandName: 'Humulin N', company: 'Lilly', forms: ['Injection', 'Vial'], strengths: ['100IU/ml']),
    ],
  ),
  DrugFormula(
    genericName: 'Insulin Glargine',
    category: 'Antidiabetic (Long-acting Insulin)',
    brands: [
      DrugBrand(brandName: 'Lantus', company: 'Sanofi', forms: ['Injection', 'Pen'], strengths: ['100IU/ml', '300IU/ml']),
      DrugBrand(brandName: 'Basaglar', company: 'Lilly', forms: ['Injection', 'Pen'], strengths: ['100IU/ml']),
    ],
  ),
];

List<DrugFormula> searchDrugs(String query) {
  if (query.isEmpty) return kPakistanDrugs;
  final q = query.toLowerCase();
  return kPakistanDrugs.where((drug) {
    if (drug.genericName.toLowerCase().contains(q)) return true;
    if (drug.category.toLowerCase().contains(q)) return true;
    for (final brand in drug.brands) {
      if (brand.brandName.toLowerCase().contains(q)) return true;
      if (brand.company.toLowerCase().contains(q)) return true;
    }
    return false;
  }).toList();
}
