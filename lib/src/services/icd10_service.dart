/// ICD-10 Code model
class Icd10Code {
  final String code;
  final String description;
  final String category;
  final List<String> synonyms;

  const Icd10Code({
    required this.code,
    required this.description,
    required this.category,
    this.synonyms = const [],
  });

  @override
  String toString() => '$code - $description';
}

/// ICD-10 Service for managing diagnosis codes
class Icd10Service {
  static final Icd10Service _instance = Icd10Service._internal();
  factory Icd10Service() => _instance;
  Icd10Service._internal();

  // Common ICD-10 codes for primary care - Essential codes only
  final List<Icd10Code> _codes = [
    // Infectious Diseases
    const Icd10Code(
      code: 'A09',
      description: 'Infectious gastroenteritis and colitis',
      category: 'Infectious',
      synonyms: ['gastroenteritis', 'diarrhea'],
    ),
    const Icd10Code(
      code: 'A15.0',
      description: 'Tuberculosis of lung',
      category: 'Infectious',
      synonyms: ['TB', 'tuberculosis'],
    ),
    const Icd10Code(
      code: 'A41.9',
      description: 'Sepsis, unspecified',
      category: 'Infectious',
      synonyms: ['sepsis', 'septicemia'],
    ),
    const Icd10Code(
      code: 'B01.0',
      description: 'Varicella meningitis',
      category: 'Infectious',
      synonyms: ['chickenpox', 'varicella'],
    ),
    const Icd10Code(
      code: 'B02.0',
      description: 'Zoster encephalitis',
      category: 'Infectious',
      synonyms: ['shingles', 'herpes zoster'],
    ),
    const Icd10Code(
      code: 'B05.9',
      description: 'Measles without complication',
      category: 'Infectious',
      synonyms: ['measles'],
    ),
    const Icd10Code(
      code: 'B16.9',
      description: 'Acute hepatitis B',
      category: 'Infectious',
      synonyms: ['hepatitis B'],
    ),
    const Icd10Code(
      code: 'B17.1',
      description: 'Acute hepatitis C',
      category: 'Infectious',
      synonyms: ['hepatitis C'],
    ),
    const Icd10Code(
      code: 'B18.1',
      description: 'Chronic viral hepatitis B',
      category: 'Infectious',
      synonyms: ['chronic hepatitis B'],
    ),
    const Icd10Code(
      code: 'B18.2',
      description: 'Chronic viral hepatitis C',
      category: 'Infectious',
      synonyms: ['chronic hepatitis C'],
    ),
    const Icd10Code(
      code: 'B24',
      description: 'Unspecified HIV disease',
      category: 'Infectious',
      synonyms: ['HIV', 'AIDS'],
    ),
    const Icd10Code(
      code: 'B35.3',
      description: 'Tinea pedis',
      category: 'Infectious',
      synonyms: ['athlete foot'],
    ),
    const Icd10Code(
      code: 'B37.0',
      description: 'Candidal stomatitis',
      category: 'Infectious',
      synonyms: ['oral thrush', 'candidiasis'],
    ),
    const Icd10Code(
      code: 'B54',
      description: 'Unspecified malaria',
      category: 'Infectious',
      synonyms: ['malaria'],
    ),
    const Icd10Code(
      code: 'B86',
      description: 'Scabies',
      category: 'Infectious',
      synonyms: ['mite infestation'],
    ),

    // Neoplasms
    const Icd10Code(
      code: 'C16.9',
      description: 'Malignant neoplasm of stomach',
      category: 'Neoplasms',
      synonyms: ['stomach cancer'],
    ),
    const Icd10Code(
      code: 'C18.9',
      description: 'Malignant neoplasm of colon',
      category: 'Neoplasms',
      synonyms: ['colon cancer'],
    ),
    const Icd10Code(
      code: 'C20',
      description: 'Malignant neoplasm of rectum',
      category: 'Neoplasms',
      synonyms: ['rectal cancer'],
    ),
    const Icd10Code(
      code: 'C22.9',
      description: 'Malignant neoplasm of liver',
      category: 'Neoplasms',
      synonyms: ['liver cancer'],
    ),
    const Icd10Code(
      code: 'C25.9',
      description: 'Malignant neoplasm of pancreas',
      category: 'Neoplasms',
      synonyms: ['pancreatic cancer'],
    ),
    const Icd10Code(
      code: 'C34.9',
      description: 'Malignant neoplasm of lung',
      category: 'Neoplasms',
      synonyms: ['lung cancer'],
    ),
    const Icd10Code(
      code: 'C44.9',
      description: 'Malignant neoplasm of skin',
      category: 'Neoplasms',
      synonyms: ['skin cancer'],
    ),
    const Icd10Code(
      code: 'C50.9',
      description: 'Malignant neoplasm of breast',
      category: 'Neoplasms',
      synonyms: ['breast cancer'],
    ),
    const Icd10Code(
      code: 'C53.9',
      description: 'Malignant neoplasm of cervix',
      category: 'Neoplasms',
      synonyms: ['cervical cancer'],
    ),
    const Icd10Code(
      code: 'C61',
      description: 'Malignant neoplasm of prostate',
      category: 'Neoplasms',
      synonyms: ['prostate cancer'],
    ),
    const Icd10Code(
      code: 'C80.1',
      description: 'Malignant neoplasm, unspecified',
      category: 'Neoplasms',
      synonyms: ['cancer', 'malignancy'],
    ),

    // Endocrine and Metabolic
    const Icd10Code(
      code: 'E05.0',
      description: 'Thyrotoxicosis with diffuse goiter',
      category: 'Endocrine',
      synonyms: ['Graves disease', 'hyperthyroidism'],
    ),
    const Icd10Code(
      code: 'E06.3',
      description: 'Autoimmune thyroiditis',
      category: 'Endocrine',
      synonyms: ['Hashimoto thyroiditis', 'hypothyroidism'],
    ),
    const Icd10Code(
      code: 'E10.9',
      description: 'Type 1 diabetes without complications',
      category: 'Endocrine',
      synonyms: ['type 1 diabetes', 'T1DM'],
    ),
    const Icd10Code(
      code: 'E11.9',
      description: 'Type 2 diabetes without complications',
      category: 'Endocrine',
      synonyms: ['type 2 diabetes', 'T2DM'],
    ),
    const Icd10Code(
      code: 'E46',
      description: 'Unspecified protein-calorie malnutrition',
      category: 'Nutritional',
      synonyms: ['malnutrition'],
    ),
    const Icd10Code(
      code: 'E66.9',
      description: 'Obesity, unspecified',
      category: 'Nutritional',
      synonyms: ['obesity'],
    ),
    const Icd10Code(
      code: 'E78.5',
      description: 'Hyperlipidemia, unspecified',
      category: 'Metabolic',
      synonyms: ['high cholesterol'],
    ),
    const Icd10Code(
      code: 'E86',
      description: 'Volume depletion',
      category: 'Metabolic',
      synonyms: ['dehydration'],
    ),

    // Mental Health
    const Icd10Code(
      code: 'F03',
      description: 'Unspecified dementia',
      category: 'Mental',
      synonyms: ['dementia'],
    ),
    const Icd10Code(
      code: 'F10.1',
      description: 'Alcohol abuse',
      category: 'Mental',
      synonyms: ['alcoholism'],
    ),
    const Icd10Code(
      code: 'F32.9',
      description: 'Depressive episode, unspecified',
      category: 'Mental',
      synonyms: ['depression'],
    ),
    const Icd10Code(
      code: 'F41.1',
      description: 'Generalized anxiety disorder',
      category: 'Mental',
      synonyms: ['GAD', 'anxiety'],
    ),
    const Icd10Code(
      code: 'F43.1',
      description: 'Post-traumatic stress disorder',
      category: 'Mental',
      synonyms: ['PTSD'],
    ),
    const Icd10Code(
      code: 'F84.0',
      description: 'Autistic disorder',
      category: 'Mental',
      synonyms: ['autism', 'ASD'],
    ),
    const Icd10Code(
      code: 'F90.0',
      description: 'Attention deficit hyperactivity disorder',
      category: 'Mental',
      synonyms: ['ADHD'],
    ),

    // Neurological
    const Icd10Code(
      code: 'G03.9',
      description: 'Meningitis, unspecified',
      category: 'Neurological',
      synonyms: ['meningitis'],
    ),
    const Icd10Code(
      code: 'G20',
      description: 'Parkinson disease',
      category: 'Neurological',
      synonyms: ['Parkinson'],
    ),
    const Icd10Code(
      code: 'G35',
      description: 'Multiple sclerosis',
      category: 'Neurological',
      synonyms: ['MS'],
    ),
    const Icd10Code(
      code: 'G40.9',
      description: 'Epilepsy, unspecified',
      category: 'Neurological',
      synonyms: ['epilepsy', 'seizures'],
    ),
    const Icd10Code(
      code: 'G43.9',
      description: 'Migraine, unspecified',
      category: 'Neurological',
      synonyms: ['migraine', 'headache'],
    ),
    const Icd10Code(
      code: 'G45.9',
      description: 'Transient cerebral ischemic attack',
      category: 'Neurological',
      synonyms: ['TIA', 'mini-stroke'],
    ),
    const Icd10Code(
      code: 'G47.3',
      description: 'Sleep apnea',
      category: 'Neurological',
      synonyms: ['sleep apnea', 'OSA'],
    ),
    const Icd10Code(
      code: 'G51.0',
      description: 'Bell palsy',
      category: 'Neurological',
      synonyms: ['facial paralysis'],
    ),
    const Icd10Code(
      code: 'G56.0',
      description: 'Carpal tunnel syndrome',
      category: 'Neurological',
      synonyms: ['carpal tunnel'],
    ),
    const Icd10Code(
      code: 'G61.0',
      description: 'Guillain-Barre syndrome',
      category: 'Neurological',
      synonyms: ['GBS'],
    ),
    const Icd10Code(
      code: 'G62.9',
      description: 'Polyneuropathy, unspecified',
      category: 'Neurological',
      synonyms: ['peripheral neuropathy'],
    ),
    const Icd10Code(
      code: 'G80.9',
      description: 'Cerebral palsy, unspecified',
      category: 'Neurological',
      synonyms: ['cerebral palsy', 'CP'],
    ),
    const Icd10Code(
      code: 'G81.9',
      description: 'Hemiplegia, unspecified',
      category: 'Neurological',
      synonyms: ['hemiplegia', 'stroke'],
    ),

    // Eye
    const Icd10Code(
      code: 'H00.0',
      description: 'Hordeolum',
      category: 'Eye',
      synonyms: ['stye'],
    ),
    const Icd10Code(
      code: 'H01.0',
      description: 'Blepharitis',
      category: 'Eye',
      synonyms: ['eyelid inflammation'],
    ),
    const Icd10Code(
      code: 'H10.0',
      description: 'Mucopurulent conjunctivitis',
      category: 'Eye',
      synonyms: ['conjunctivitis', 'pink eye'],
    ),
    const Icd10Code(
      code: 'H25.9',
      description: 'Senile cataract',
      category: 'Eye',
      synonyms: ['cataract'],
    ),
    const Icd10Code(
      code: 'H40.9',
      description: 'Glaucoma, unspecified',
      category: 'Eye',
      synonyms: ['glaucoma'],
    ),
    const Icd10Code(
      code: 'H52.1',
      description: 'Myopia',
      category: 'Eye',
      synonyms: ['nearsightedness'],
    ),
    const Icd10Code(
      code: 'H54.0',
      description: 'Blindness, binocular',
      category: 'Eye',
      synonyms: ['blindness'],
    ),

    // Ear
    const Icd10Code(
      code: 'H60.9',
      description: 'Otitis externa',
      category: 'Ear',
      synonyms: ['ear infection', 'swimmer ear'],
    ),
    const Icd10Code(
      code: 'H66.0',
      description: 'Acute suppurative otitis media',
      category: 'Ear',
      synonyms: ['ear infection', 'earache'],
    ),
    const Icd10Code(
      code: 'H81.0',
      description: 'Meniere disease',
      category: 'Ear',
      synonyms: ['Meniere', 'vertigo'],
    ),
    const Icd10Code(
      code: 'H91.9',
      description: 'Hearing loss, unspecified',
      category: 'Ear',
      synonyms: ['hearing loss', 'deafness'],
    ),

    // Cardiovascular
    const Icd10Code(
      code: 'I10',
      description: 'Essential hypertension',
      category: 'Cardiovascular',
      synonyms: ['hypertension', 'high blood pressure'],
    ),
    const Icd10Code(
      code: 'I20.9',
      description: 'Angina pectoris',
      category: 'Cardiovascular',
      synonyms: ['angina', 'chest pain'],
    ),
    const Icd10Code(
      code: 'I21.9',
      description: 'Acute myocardial infarction',
      category: 'Cardiovascular',
      synonyms: ['heart attack', 'MI'],
    ),
    const Icd10Code(
      code: 'I25.1',
      description: 'Atherosclerotic heart disease',
      category: 'Cardiovascular',
      synonyms: ['CAD', 'coronary artery disease'],
    ),
    const Icd10Code(
      code: 'I26.9',
      description: 'Pulmonary embolism',
      category: 'Cardiovascular',
      synonyms: ['PE', 'blood clot in lung'],
    ),
    const Icd10Code(
      code: 'I33.0',
      description: 'Acute infective endocarditis',
      category: 'Cardiovascular',
      synonyms: ['endocarditis'],
    ),
    const Icd10Code(
      code: 'I34.0',
      description: 'Nonrheumatic mitral insufficiency',
      category: 'Cardiovascular',
      synonyms: ['mitral regurgitation'],
    ),
    const Icd10Code(
      code: 'I35.0',
      description: 'Nonrheumatic aortic stenosis',
      category: 'Cardiovascular',
      synonyms: ['aortic stenosis'],
    ),
    const Icd10Code(
      code: 'I42.0',
      description: 'Dilated cardiomyopathy',
      category: 'Cardiovascular',
      synonyms: ['DCM', 'cardiomyopathy'],
    ),
    const Icd10Code(
      code: 'I48',
      description: 'Atrial fibrillation and flutter',
      category: 'Cardiovascular',
      synonyms: ['AFib', 'atrial fibrillation'],
    ),
    const Icd10Code(
      code: 'I50.9',
      description: 'Heart failure, unspecified',
      category: 'Cardiovascular',
      synonyms: ['heart failure', 'CHF'],
    ),
    const Icd10Code(
      code: 'I63.9',
      description: 'Cerebral infarction, unspecified',
      category: 'Cardiovascular',
      synonyms: ['ischemic stroke', 'stroke'],
    ),
    const Icd10Code(
      code: 'I64',
      description: 'Stroke, not specified as hemorrhage or infarction',
      category: 'Cardiovascular',
      synonyms: ['stroke', 'CVA'],
    ),
    const Icd10Code(
      code: 'I67.9',
      description: 'Cerebrovascular disease, unspecified',
      category: 'Cardiovascular',
      synonyms: ['CVD'],
    ),
    const Icd10Code(
      code: 'I70.2',
      description: 'Atherosclerosis of arteries of extremities',
      category: 'Cardiovascular',
      synonyms: ['PAD', 'peripheral artery disease'],
    ),
    const Icd10Code(
      code: 'I71.9',
      description: 'Aortic aneurysm, unspecified',
      category: 'Cardiovascular',
      synonyms: ['aortic aneurysm'],
    ),
    const Icd10Code(
      code: 'I80.2',
      description: 'Phlebitis and thrombophlebitis of lower extremities',
      category: 'Cardiovascular',
      synonyms: ['DVT', 'deep vein thrombosis'],
    ),
    const Icd10Code(
      code: 'I83.9',
      description: 'Varicose veins of lower extremities',
      category: 'Cardiovascular',
      synonyms: ['varicose veins'],
    ),
    const Icd10Code(
      code: 'I95.9',
      description: 'Hypotension, unspecified',
      category: 'Cardiovascular',
      synonyms: ['low blood pressure'],
    ),

    // Respiratory
    const Icd10Code(
      code: 'J00',
      description: 'Acute nasopharyngitis [common cold]',
      category: 'Respiratory',
      synonyms: ['common cold', 'cold'],
    ),
    const Icd10Code(
      code: 'J01.0',
      description: 'Acute maxillary sinusitis',
      category: 'Respiratory',
      synonyms: ['sinusitis', 'sinus infection'],
    ),
    const Icd10Code(
      code: 'J02.9',
      description: 'Acute pharyngitis, unspecified',
      category: 'Respiratory',
      synonyms: ['sore throat', 'pharyngitis'],
    ),
    const Icd10Code(
      code: 'J03.9',
      description: 'Acute tonsillitis, unspecified',
      category: 'Respiratory',
      synonyms: ['tonsillitis'],
    ),
    const Icd10Code(
      code: 'J04.0',
      description: 'Acute laryngitis',
      category: 'Respiratory',
      synonyms: ['laryngitis'],
    ),
    const Icd10Code(
      code: 'J05.0',
      description: 'Acute obstructive laryngitis [croup]',
      category: 'Respiratory',
      synonyms: ['croup'],
    ),
    const Icd10Code(
      code: 'J06.9',
      description: 'Acute upper respiratory infection, unspecified',
      category: 'Respiratory',
      synonyms: ['URI', 'upper respiratory infection'],
    ),
    const Icd10Code(
      code: 'J09',
      description: 'Influenza due to certain identified influenza virus',
      category: 'Respiratory',
      synonyms: ['flu', 'influenza'],
    ),
    const Icd10Code(
      code: 'J10.1',
      description: 'Influenza with other respiratory manifestations',
      category: 'Respiratory',
      synonyms: ['flu', 'influenza'],
    ),
    const Icd10Code(
      code: 'J11.1',
      description:
          'Influenza with other respiratory manifestations, virus not identified',
      category: 'Respiratory',
      synonyms: ['flu', 'influenza'],
    ),
    const Icd10Code(
      code: 'J12.9',
      description: 'Viral pneumonia, unspecified',
      category: 'Respiratory',
      synonyms: ['viral pneumonia', 'pneumonia'],
    ),
    const Icd10Code(
      code: 'J13',
      description: 'Pneumonia due to Streptococcus pneumoniae',
      category: 'Respiratory',
      synonyms: ['pneumococcal pneumonia', 'pneumonia'],
    ),
    const Icd10Code(
      code: 'J15.9',
      description: 'Unspecified bacterial pneumonia',
      category: 'Respiratory',
      synonyms: ['bacterial pneumonia', 'pneumonia'],
    ),
    const Icd10Code(
      code: 'J18.9',
      description: 'Pneumonia, unspecified organism',
      category: 'Respiratory',
      synonyms: ['pneumonia', 'lung infection'],
    ),
    const Icd10Code(
      code: 'J20.9',
      description: 'Acute bronchitis, unspecified',
      category: 'Respiratory',
      synonyms: ['bronchitis', 'chest cold'],
    ),
    const Icd10Code(
      code: 'J22',
      description: 'Unspecified acute lower respiratory infection',
      category: 'Respiratory',
      synonyms: ['lower respiratory infection'],
    ),
    const Icd10Code(
      code: 'J30.4',
      description: 'Allergic rhinitis, unspecified',
      category: 'Respiratory',
      synonyms: ['allergic rhinitis', 'hay fever', 'allergies'],
    ),
    const Icd10Code(
      code: 'J32.9',
      description: 'Chronic sinusitis, unspecified',
      category: 'Respiratory',
      synonyms: ['chronic sinusitis'],
    ),
    const Icd10Code(
      code: 'J40',
      description: 'Bronchitis, not specified as acute or chronic',
      category: 'Respiratory',
      synonyms: ['bronchitis'],
    ),
    const Icd10Code(
      code: 'J41.0',
      description: 'Simple chronic bronchitis',
      category: 'Respiratory',
      synonyms: ['chronic bronchitis'],
    ),
    const Icd10Code(
      code: 'J42',
      description: 'Unspecified chronic bronchitis',
      category: 'Respiratory',
      synonyms: ['chronic bronchitis'],
    ),
    const Icd10Code(
      code: 'J43.9',
      description: 'Emphysema, unspecified',
      category: 'Respiratory',
      synonyms: ['emphysema', 'COPD'],
    ),
    const Icd10Code(
      code: 'J44.0',
      description: 'COPD with acute lower respiratory infection',
      category: 'Respiratory',
      synonyms: ['COPD', 'chronic obstructive pulmonary disease'],
    ),
    const Icd10Code(
      code: 'J44.1',
      description: 'COPD with acute exacerbation',
      category: 'Respiratory',
      synonyms: ['COPD exacerbation', 'COPD flare'],
    ),
    const Icd10Code(
      code: 'J44.9',
      description: 'COPD, unspecified',
      category: 'Respiratory',
      synonyms: ['COPD', 'chronic obstructive pulmonary disease'],
    ),
    const Icd10Code(
      code: 'J45.9',
      description: 'Asthma, unspecified',
      category: 'Respiratory',
      synonyms: ['asthma'],
    ),
    const Icd10Code(
      code: 'J46',
      description: 'Status asthmaticus',
      category: 'Respiratory',
      synonyms: ['severe asthma', 'asthma attack'],
    ),
    const Icd10Code(
      code: 'J47',
      description: 'Bronchiectasis',
      category: 'Respiratory',
      synonyms: ['bronchiectasis'],
    ),
    const Icd10Code(
      code: 'J80',
      description: 'Acute respiratory distress syndrome',
      category: 'Respiratory',
      synonyms: ['ARDS', 'acute respiratory distress'],
    ),
    const Icd10Code(
      code: 'J81.0',
      description: 'Acute pulmonary edema',
      category: 'Respiratory',
      synonyms: ['pulmonary edema', 'fluid in lungs'],
    ),
    const Icd10Code(
      code: 'J84.1',
      description: 'Other interstitial pulmonary diseases with fibrosis',
      category: 'Respiratory',
      synonyms: ['pulmonary fibrosis'],
    ),
    const Icd10Code(
      code: 'J90',
      description: 'Pleural effusion, not elsewhere classified',
      category: 'Respiratory',
      synonyms: ['pleural effusion', 'fluid around lungs'],
    ),
    const Icd10Code(
      code: 'J93.9',
      description: 'Pneumothorax, unspecified',
      category: 'Respiratory',
      synonyms: ['pneumothorax', 'collapsed lung'],
    ),
    const Icd10Code(
      code: 'J96.0',
      description: 'Acute respiratory failure',
      category: 'Respiratory',
      synonyms: ['respiratory failure', 'ARF'],
    ),
    const Icd10Code(
      code: 'J96.9',
      description: 'Respiratory failure, unspecified',
      category: 'Respiratory',
      synonyms: ['respiratory failure'],
    ),
    const Icd10Code(
      code: 'J98.9',
      description: 'Respiratory disorder, unspecified',
      category: 'Respiratory',
      synonyms: ['respiratory disorder'],
    ),

    // Digestive
    const Icd10Code(
      code: 'K02.9',
      description: 'Dental caries, unspecified',
      category: 'Digestive',
      synonyms: ['cavities', 'tooth decay'],
    ),
    const Icd10Code(
      code: 'K05.0',
      description: 'Acute gingivitis',
      category: 'Digestive',
      synonyms: ['gingivitis', 'gum inflammation'],
    ),
    const Icd10Code(
      code: 'K05.1',
      description: 'Chronic gingivitis',
      category: 'Digestive',
      synonyms: ['chronic gingivitis', 'gum disease'],
    ),
    const Icd10Code(
      code: 'K12.0',
      description: 'Recurrent oral aphthae',
      category: 'Digestive',
      synonyms: ['canker sores', 'mouth ulcers'],
    ),
    const Icd10Code(
      code: 'K21.0',
      description: 'Gastro-esophageal reflux disease with esophagitis',
      category: 'Digestive',
      synonyms: ['GERD', 'acid reflux', 'heartburn'],
    ),
    const Icd10Code(
      code: 'K21.9',
      description: 'Gastro-esophageal reflux disease without esophagitis',
      category: 'Digestive',
      synonyms: ['GERD', 'acid reflux', 'heartburn'],
    ),
    const Icd10Code(
      code: 'K25.9',
      description: 'Gastric ulcer, unspecified',
      category: 'Digestive',
      synonyms: ['gastric ulcer', 'stomach ulcer'],
    ),
    const Icd10Code(
      code: 'K26.9',
      description: 'Duodenal ulcer, unspecified',
      category: 'Digestive',
      synonyms: ['duodenal ulcer', 'peptic ulcer'],
    ),
    const Icd10Code(
      code: 'K29.0',
      description: 'Acute gastritis',
      category: 'Digestive',
      synonyms: ['gastritis', 'stomach inflammation'],
    ),
    const Icd10Code(
      code: 'K29.7',
      description: 'Gastritis, unspecified',
      category: 'Digestive',
      synonyms: ['gastritis', 'stomach inflammation'],
    ),
    const Icd10Code(
      code: 'K30',
      description: 'Functional dyspepsia',
      category: 'Digestive',
      synonyms: ['indigestion', 'dyspepsia'],
    ),
    const Icd10Code(
      code: 'K35.2',
      description: 'Acute appendicitis with generalized peritonitis',
      category: 'Digestive',
      synonyms: ['appendicitis', 'ruptured appendix'],
    ),
    const Icd10Code(
      code: 'K35.3',
      description: 'Acute appendicitis with localized peritonitis',
      category: 'Digestive',
      synonyms: ['appendicitis'],
    ),
    const Icd10Code(
      code: 'K35.8',
      description: 'Other and unspecified acute appendicitis',
      category: 'Digestive',
      synonyms: ['appendicitis'],
    ),
    const Icd10Code(
      code: 'K40.9',
      description:
          'Unilateral inguinal hernia, without obstruction or gangrene',
      category: 'Digestive',
      synonyms: ['inguinal hernia'],
    ),
    const Icd10Code(
      code: 'K41.9',
      description: 'Unilateral femoral hernia, without obstruction or gangrene',
      category: 'Digestive',
      synonyms: ['femoral hernia'],
    ),
    const Icd10Code(
      code: 'K42.9',
      description: 'Umbilical hernia without obstruction or gangrene',
      category: 'Digestive',
      synonyms: ['umbilical hernia', 'belly button hernia'],
    ),
    const Icd10Code(
      code: 'K44.9',
      description: 'Diaphragmatic hernia without obstruction or gangrene',
      category: 'Digestive',
      synonyms: ['hiatal hernia', 'diaphragmatic hernia'],
    ),
    const Icd10Code(
      code: 'K50.9',
      description: 'Crohn disease, unspecified',
      category: 'Digestive',
      synonyms: ['Crohn disease', 'Crohn', 'inflammatory bowel disease'],
    ),
    const Icd10Code(
      code: 'K51.9',
      description: 'Ulcerative colitis, unspecified',
      category: 'Digestive',
      synonyms: ['ulcerative colitis', 'UC', 'inflammatory bowel disease'],
    ),
    const Icd10Code(
      code: 'K52.9',
      description: 'Noninfective gastroenteritis and colitis, unspecified',
      category: 'Digestive',
      synonyms: ['gastroenteritis', 'colitis'],
    ),
    const Icd10Code(
      code: 'K56.0',
      description: 'Paralytic ileus',
      category: 'Digestive',
      synonyms: ['ileus', 'bowel obstruction'],
    ),
    const Icd10Code(
      code: 'K56.5',
      description: 'Intestinal adhesions [bands] with obstruction',
      category: 'Digestive',
      synonyms: ['bowel obstruction', 'adhesions'],
    ),
    const Icd10Code(
      code: 'K57.0',
      description:
          'Diverticulitis of small intestine with perforation and abscess',
      category: 'Digestive',
      synonyms: ['diverticulitis'],
    ),
    const Icd10Code(
      code: 'K57.2',
      description:
          'Diverticulitis of large intestine with perforation and abscess',
      category: 'Digestive',
      synonyms: ['diverticulitis'],
    ),
    const Icd10Code(
      code: 'K57.9',
      description: 'Diverticular disease of intestine, unspecified',
      category: 'Digestive',
      synonyms: ['diverticulosis', 'diverticular disease'],
    ),
    const Icd10Code(
      code: 'K58.9',
      description: 'Irritable bowel syndrome without diarrhea',
      category: 'Digestive',
      synonyms: ['IBS', 'irritable bowel syndrome'],
    ),
    const Icd10Code(
      code: 'K59.0',
      description: 'Constipation',
      category: 'Digestive',
      synonyms: ['constipation'],
    ),
    const Icd10Code(
      code: 'K59.1',
      description: 'Functional diarrhea',
      category: 'Digestive',
      synonyms: ['diarrhea', 'chronic diarrhea'],
    ),
    const Icd10Code(
      code: 'K59.9',
      description: 'Functional intestinal disorder, unspecified',
      category: 'Digestive',
      synonyms: ['intestinal disorder'],
    ),
    const Icd10Code(
      code: 'K60.0',
      description: 'Acute anal fissure',
      category: 'Digestive',
      synonyms: ['anal fissure'],
    ),
    const Icd10Code(
      code: 'K60.2',
      description: 'Anal fissure, unspecified',
      category: 'Digestive',
      synonyms: ['anal fissure'],
    ),
    const Icd10Code(
      code: 'K61.0',
      description: 'Anal abscess',
      category: 'Digestive',
      synonyms: ['perianal abscess', 'anal abscess'],
    ),
    const Icd10Code(
      code: 'K62.5',
      description: 'Hemorrhage of anus and rectum',
      category: 'Digestive',
      synonyms: ['rectal bleeding', 'anal bleeding'],
    ),
    const Icd10Code(
      code: 'K63.5',
      description: 'Polyp of colon',
      category: 'Digestive',
      synonyms: ['colon polyp', 'colonic polyp'],
    ),
    const Icd10Code(
      code: 'K64.0',
      description: 'First degree hemorrhoids',
      category: 'Digestive',
      synonyms: ['hemorrhoids', 'piles'],
    ),
    const Icd10Code(
      code: 'K64.1',
      description: 'Second degree hemorrhoids',
      category: 'Digestive',
      synonyms: ['hemorrhoids', 'piles'],
    ),
    const Icd10Code(
      code: 'K64.2',
      description: 'Third degree hemorrhoids',
      category: 'Digestive',
      synonyms: ['hemorrhoids', 'piles'],
    ),
    const Icd10Code(
      code: 'K64.3',
      description: 'Fourth degree hemorrhoids',
      category: 'Digestive',
      synonyms: ['hemorrhoids', 'piles'],
    ),
    const Icd10Code(
      code: 'K64.9',
      description: 'Hemorrhoids, unspecified',
      category: 'Digestive',
      synonyms: ['hemorrhoids', 'piles'],
    ),
    const Icd10Code(
      code: 'K70.0',
      description: 'Alcoholic fatty liver',
      category: 'Digestive',
      synonyms: ['fatty liver', 'alcoholic liver disease'],
    ),
    const Icd10Code(
      code: 'K70.3',
      description: 'Alcoholic cirrhosis of liver',
      category: 'Digestive',
      synonyms: ['alcoholic cirrhosis', 'liver cirrhosis'],
    ),
    const Icd10Code(
      code: 'K70.9',
      description: 'Alcoholic liver disease, unspecified',
      category: 'Digestive',
      synonyms: ['alcoholic liver disease'],
    ),
    const Icd10Code(
      code: 'K71.0',
      description: 'Toxic liver disease with cholestasis',
      category: 'Digestive',
      synonyms: ['drug-induced liver disease', 'toxic hepatitis'],
    ),
    const Icd10Code(
      code: 'K72.0',
      description: 'Acute and subacute hepatic failure',
      category: 'Digestive',
      synonyms: ['acute liver failure', 'hepatic failure'],
    ),
    const Icd10Code(
      code: 'K72.9',
      description: 'Hepatic failure, unspecified',
      category: 'Digestive',
      synonyms: ['liver failure', 'hepatic failure'],
    ),
    const Icd10Code(
      code: 'K73.9',
      description: 'Chronic hepatitis, unspecified',
      category: 'Digestive',
      synonyms: ['chronic hepatitis'],
    ),
    const Icd10Code(
      code: 'K74.0',
      description: 'Hepatic fibrosis',
      category: 'Digestive',
      synonyms: ['liver fibrosis', 'hepatic fibrosis'],
    ),
    const Icd10Code(
      code: 'K74.3',
      description: 'Primary biliary cirrhosis',
      category: 'Digestive',
      synonyms: ['PBC', 'primary biliary cholangitis'],
    ),
    const Icd10Code(
      code: 'K74.6',
      description: 'Other and unspecified cirrhosis of liver',
      category: 'Digestive',
      synonyms: ['cirrhosis', 'liver cirrhosis'],
    ),
    const Icd10Code(
      code: 'K75.0',
      description: 'Abscess of liver',
      category: 'Digestive',
      synonyms: ['liver abscess', 'hepatic abscess'],
    ),
    const Icd10Code(
      code: 'K75.9',
      description: 'Inflammatory liver disease, unspecified',
      category: 'Digestive',
      synonyms: ['hepatitis', 'liver inflammation'],
    ),
    const Icd10Code(
      code: 'K76.0',
      description: 'Fatty (change of) liver, not elsewhere classified',
      category: 'Digestive',
      synonyms: ['fatty liver', 'NAFLD', 'hepatic steatosis'],
    ),
    const Icd10Code(
      code: 'K76.6',
      description: 'Portal hypertension',
      category: 'Digestive',
      synonyms: ['portal hypertension'],
    ),
    const Icd10Code(
      code: 'K76.9',
      description: 'Liver disease, unspecified',
      category: 'Digestive',
      synonyms: ['liver disease', 'hepatic disease'],
    ),
    const Icd10Code(
      code: 'K80.0',
      description: 'Calculus of gallbladder with acute cholecystitis',
      category: 'Digestive',
      synonyms: ['gallstones', 'gallbladder stones', 'cholelithiasis'],
    ),
    const Icd10Code(
      code: 'K80.2',
      description: 'Calculus of gallbladder without cholecystitis',
      category: 'Digestive',
      synonyms: ['gallstones', 'cholelithiasis'],
    ),
    const Icd10Code(
      code: 'K80.5',
      description: 'Calculus of bile duct without cholangitis or cholecystitis',
      category: 'Digestive',
      synonyms: ['bile duct stones', 'choledocholithiasis'],
    ),
    const Icd10Code(
      code: 'K81.0',
      description: 'Acute cholecystitis',
      category: 'Digestive',
      synonyms: ['cholecystitis', 'gallbladder inflammation'],
    ),
    const Icd10Code(
      code: 'K81.9',
      description: 'Cholecystitis, unspecified',
      category: 'Digestive',
      synonyms: ['cholecystitis'],
    ),
    const Icd10Code(
      code: 'K82.0',
      description: 'Obstruction of gallbladder',
      category: 'Digestive',
      synonyms: ['gallbladder obstruction'],
    ),
    const Icd10Code(
      code: 'K83.0',
      description: 'Cholangitis',
      category: 'Digestive',
      synonyms: ['bile duct inflammation', 'cholangitis'],
    ),
    const Icd10Code(
      code: 'K83.1',
      description: 'Obstruction of bile duct',
      category: 'Digestive',
      synonyms: ['bile duct obstruction', 'biliary obstruction'],
    ),
    const Icd10Code(
      code: 'K85.0',
      description: 'Idiopathic acute pancreatitis',
      category: 'Digestive',
      synonyms: ['acute pancreatitis', 'pancreatitis'],
    ),
    const Icd10Code(
      code: 'K85.1',
      description: 'Biliary acute pancreatitis',
      category: 'Digestive',
      synonyms: ['gallstone pancreatitis', 'acute pancreatitis'],
    ),
    const Icd10Code(
      code: 'K85.2',
      description: 'Alcohol-induced acute pancreatitis',
      category: 'Digestive',
      synonyms: ['alcoholic pancreatitis', 'acute pancreatitis'],
    ),
    const Icd10Code(
      code: 'K85.3',
      description: 'Drug-induced acute pancreatitis',
      category: 'Digestive',
      synonyms: ['drug-induced pancreatitis', 'acute pancreatitis'],
    ),
    const Icd10Code(
      code: 'K85.9',
      description: 'Acute pancreatitis, unspecified',
      category: 'Digestive',
      synonyms: ['acute pancreatitis', 'pancreatitis'],
    ),
    const Icd10Code(
      code: 'K86.0',
      description: 'Alcohol-induced chronic pancreatitis',
      category: 'Digestive',
      synonyms: ['chronic pancreatitis', 'alcoholic pancreatitis'],
    ),
    const Icd10Code(
      code: 'K86.1',
      description: 'Other chronic pancreatitis',
      category: 'Digestive',
      synonyms: ['chronic pancreatitis'],
    ),
    const Icd10Code(
      code: 'K86.2',
      description: 'Cyst of pancreas',
      category: 'Digestive',
      synonyms: ['pancreatic cyst'],
    ),
    const Icd10Code(
      code: 'K86.3',
      description: 'Pseudocyst of pancreas',
      category: 'Digestive',
      synonyms: ['pancreatic pseudocyst'],
    ),
    const Icd10Code(
      code: 'K86.9',
      description: 'Other diseases of pancreas',
      category: 'Digestive',
      synonyms: ['pancreatic disease'],
    ),
  ];

  /// Get all ICD-10 codes
  List<Icd10Code> getAllCodes() => List.unmodifiable(_codes);

  /// Get codes by category
  List<Icd10Code> getCodesByCategory(String category) {
    return _codes.where((code) => code.category == category).toList();
  }

  /// Get all available categories
  List<String> getCategories() {
    return _codes.map((code) => code.category).toSet().toList()..sort();
  }

  /// Search codes by query string
  List<Icd10Code> searchCodes(String query) {
    if (query.isEmpty) return getAllCodes();

    final lowerQuery = query.toLowerCase();
    final results = <Icd10Code>[];

    for (final code in _codes) {
      // Check code match
      if (code.code.toLowerCase().contains(lowerQuery)) {
        results.add(code);
        continue;
      }

      // Check description match
      if (code.description.toLowerCase().contains(lowerQuery)) {
        results.add(code);
        continue;
      }

      // Check synonyms match
      for (final synonym in code.synonyms) {
        if (synonym.toLowerCase().contains(lowerQuery)) {
          results.add(code);
          break;
        }
      }
    }

    return results;
  }

  /// Find exact code by ICD-10 code
  Icd10Code? findByCode(String code) {
    try {
      return _codes.firstWhere(
        (c) => c.code.toLowerCase() == code.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Get top common codes for quick selection
  List<Icd10Code> getCommonCodes() {
    final commonCodeList = [
      'J00',
      'J06.9',
      'J18.9',
      'J44.9',
      'J45.9',
      'K21.9',
      'K29.7',
      'K30',
      'K35.8',
      'E11.9',
      'E66.9',
      'E78.5',
      'I10',
      'I20.9',
      'I21.9',
      'I25.1',
      'I48',
      'I50.9',
      'F32.9',
      'F41.1',
      'G43.9',
      'G40.9',
      'H10.0',
      'H25.9',
      'B37.0',
      'A09',
    ];

    return commonCodeList
        .map((code) => findByCode(code))
        .where((code) => code != null)
        .cast<Icd10Code>()
        .toList();
  }
}
