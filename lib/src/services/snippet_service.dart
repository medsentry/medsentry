import '../database/simple_database.dart';

class SnippetService {
  final SimpleDatabase _db;

  SnippetService(this._db);

  /// Default medical snippets that come with the app
  static final List<MedicalSnippet> _defaultSnippets = [
    MedicalSnippet(
      id: 'snippet_htn',
      shortcut: '/htn',
      title: 'Hypertension Management',
      content: '''1. Lifestyle modifications:
   - DASH diet (low sodium, high potassium)
   - Regular exercise 30 min/day, 5 days/week
   - Weight reduction if BMI >25
   - Limit alcohol, quit smoking

2. Home BP monitoring:
   - Check twice daily (AM and PM)
   - Record in BP log book
   - Target: <140/90 mmHg

3. Medications as prescribed
4. Follow-up in 2 weeks or earlier if BP >180/110''',
      category: 'chronic',
    ),
    MedicalSnippet(
      id: 'snippet_dm',
      shortcut: '/dm',
      title: 'Diabetes Management',
      content: '''1. Diet control:
   - Low carbohydrate diet
   - Portion control (plate method)
   - Increase fiber intake
   - Limit sugary drinks

2. Exercise:
   - 30 minutes moderate activity daily
   - Walking, swimming, or cycling

3. Monitoring:
   - Check blood glucose regularly
   - HbA1c every 3 months
   - Target: FBS <7 mmol/L, HbA1c <7%

4. Foot care daily inspection
5. Take medications as prescribed
6. Follow-up in 1 month''',
      category: 'chronic',
    ),
    MedicalSnippet(
      id: 'snippet_uri',
      shortcut: '/uri',
      title: 'Upper Respiratory Infection',
      content: '''1. Symptomatic treatment:
   - Paracetamol 500mg 1 tab every 4-6 hours for fever/pain
   - Increase fluid intake (8-10 glasses/day)
   - Rest and adequate sleep

2. Home care:
   - Warm saline gargle 3x daily
   - Steam inhalation
   - Honey for cough (if not diabetic)

3. When to return immediately:
   - Difficulty breathing
   - Chest pain
   - High fever >3 days
   - Symptoms worsen

4. Return if not improved in 7 days''',
      category: 'acute',
    ),
    MedicalSnippet(
      id: 'snippet_prenatal',
      shortcut: '/prenatal',
      title: 'Prenatal Visit',
      content: '''1. Monitoring:
   - Weight, BP, urine protein
   - Fetal heart tones
   - Fundal height measurement

2. Supplements:
   - Ferrous sulfate 1 tab daily
   - Folic acid 400mcg daily
   - Calcium carbonate 500mg 2x daily

3. Advice:
   - Balanced diet, increase protein
   - Avoid alcohol and smoking
   - Light exercise (walking)
   - Sleep on left side

4. Danger signs to report:
   - Vaginal bleeding
   - Severe headache/blurred vision
   - Decreased fetal movement
   - Severe abdominal pain

5. Next visit scheduled''',
      category: 'maternal',
    ),
    MedicalSnippet(
      id: 'snippet_cough',
      shortcut: '/cough',
      title: 'Cough Management',
      content: '''1. Assessment:
   - Duration of cough
   - Productive vs dry
   - Associated fever/weight loss

2. Treatment:
   - Hydration: 8-10 glasses water daily
   - Honey 1 tsp 3x daily (if not diabetic)
   - Avoid irritants (smoke, dust)

3. Medications if needed:
   - Carbocisteine for productive cough
   - Dextromethorphan for dry cough

4. Return if:
   - Cough >2 weeks
   - Blood in sputum
   - Weight loss/night sweats
   - Difficulty breathing''',
      category: 'respiratory',
    ),
    MedicalSnippet(
      id: 'snippet_diarrhea',
      shortcut: '/diarrhea',
      title: 'Diarrhea Management',
      content: '''1. Rehydration (most important):
   - ORS: 1 sachet in 1 liter clean water
   - Sip small amounts frequently
   - Continue even if vomiting

2. Diet:
   - Continue breastfeeding (infants)
   - BRAT diet: Banana, Rice, Applesauce, Toast
   - Avoid fatty, spicy foods

3. Medications:
   - Zinc supplements (reduces duration)
   - Loperamide only if no fever/blood

4. Warning signs - return immediately:
   - Blood in stool
   - Severe dehydration (very thirsty, dry mouth, no urine)
   - High fever
   - Persistent vomiting

5. Follow-up in 2 days if not improved''',
      category: 'gi',
    ),
    MedicalSnippet(
      id: 'snippet_wound',
      shortcut: '/wound',
      title: 'Wound Care',
      content: '''1. Cleaning:
   - Wash hands before touching wound
   - Clean with sterile saline or clean water
   - Remove debris gently
   - Pat dry with clean gauze

2. Dressing:
   - Apply antibiotic ointment (if prescribed)
   - Cover with sterile dressing
   - Change daily or when soiled

3. Monitoring:
   - Watch for infection: redness, warmth, swelling, pus, fever
   - Keep wound dry (no swimming)

4. Tetanus:
   - Check last tetanus shot
   - Booster if >5 years or dirty wound

5. Return if signs of infection or not healing in 1 week''',
      category: 'emergency',
    ),
    MedicalSnippet(
      id: 'snippet_anemia',
      shortcut: '/anemia',
      title: 'Anemia Management',
      content: '''1. Iron supplementation:
   - Ferrous sulfate 1 tab 2x daily
   - Take with vitamin C (orange juice)
   - Avoid tea/coffee within 2 hours

2. Dietary advice:
   - Iron-rich foods: liver, lean meat, leafy greens
   - Vitamin C foods to enhance absorption
   - Avoid calcium-rich foods with iron

3. Side effects:
   - Constipation (increase fiber)
   - Dark stools (normal)
   - Nausea (take with food)

4. Monitoring:
   - Repeat CBC in 1 month
   - Continue iron for 3 months after Hb normalizes

5. Follow-up in 4 weeks''',
      category: 'hematology',
    ),
  ];

  /// Initialize default snippets in database
  Future<void> initializeDefaultSnippets() async {
    // Check if snippets already exist
    final existing = await _db.getMedicalSnippets();
    if (existing.isEmpty) {
      for (final snippet in _defaultSnippets) {
        await _db.insertMedicalSnippet(snippet);
      }
    }
  }

  /// Get all active snippets
  Future<List<MedicalSnippet>> getAllSnippets() async {
    final snippets = await _db.getMedicalSnippets();
    return snippets.cast<MedicalSnippet>();
  }

  /// Get snippets by category
  Future<List<MedicalSnippet>> getSnippetsByCategory(String category) async {
    final all = await _db.getMedicalSnippets();
    return all
        .cast<MedicalSnippet>()
        .where((s) => s.category == category)
        .toList();
  }

  /// Find snippet by shortcut
  Future<MedicalSnippet?> findSnippetByShortcut(String shortcut) async {
    final all = await _db.getMedicalSnippets();
    try {
      return all.firstWhere(
        (s) => s.shortcut.toLowerCase() == shortcut.toLowerCase(),
      );
    } catch (e) {
      return null;
    }
  }

  /// Expand text with snippets
  /// Example: "Patient has /htn" -> "Patient has [full hypertension text]"
  Future<String> expandSnippets(String text) async {
    final snippets = await _db.getMedicalSnippets();
    String result = text;

    for (final snippet in snippets) {
      result = result.replaceAll(snippet.shortcut, snippet.content);
    }

    return result;
  }

  /// Check if text contains any snippet shortcuts
  Future<bool> containsShortcut(String text) async {
    final snippets = await _db.getMedicalSnippets();
    return snippets.any((s) => text.contains(s.shortcut));
  }

  /// Get list of shortcuts for autocomplete
  Future<List<String>> getShortcuts() async {
    final snippets = await _db.getMedicalSnippets();
    return snippets.cast<MedicalSnippet>().map((s) => s.shortcut).toList();
  }

  /// Create custom snippet
  Future<MedicalSnippet> createSnippet({
    required String shortcut,
    required String title,
    required String content,
    String? category,
  }) async {
    // Validate shortcut format (should start with /)
    if (!shortcut.startsWith('/')) {
      throw ArgumentError('Shortcut must start with /');
    }

    // Check if shortcut already exists
    final existing = await findSnippetByShortcut(shortcut);
    if (existing != null) {
      throw ArgumentError('Shortcut $shortcut already exists');
    }

    final snippet = MedicalSnippet(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      shortcut: shortcut,
      title: title,
      content: content,
      category: category ?? 'custom',
    );

    await _db.insertMedicalSnippet(snippet);
    return snippet;
  }

  /// Update snippet
  Future<MedicalSnippet> updateSnippet({
    required String id,
    String? shortcut,
    String? title,
    String? content,
    String? category,
    bool? isActive,
  }) async {
    final existing = await _db.getMedicalSnippetById(id);
    if (existing == null) {
      throw ArgumentError('Snippet not found: $id');
    }

    final updated = existing.copyWith(
      shortcut: shortcut ?? existing.shortcut,
      title: title ?? existing.title,
      content: content ?? existing.content,
      category: category ?? existing.category,
      isActive: isActive ?? existing.isActive,
      updatedAt: DateTime.now(),
    );

    await _db.updateMedicalSnippet(updated);
    return updated;
  }

  /// Delete snippet
  Future<void> deleteSnippet(String id) async {
    await _db.deleteMedicalSnippet(id);
  }

  /// Search snippets
  Future<List<MedicalSnippet>> searchSnippets(String query) async {
    final all = await _db.getMedicalSnippets();
    final lowerQuery = query.toLowerCase();
    return all.cast<MedicalSnippet>().where((s) {
      return s.title.toLowerCase().contains(lowerQuery) ||
          s.shortcut.toLowerCase().contains(lowerQuery) ||
          (s.category?.toLowerCase().contains(lowerQuery) ?? false);
    }).toList();
  }
}

/// Model for medical snippets
class MedicalSnippet {
  final String id;
  final String shortcut;
  final String title;
  final String content;
  final String? category;
  final bool isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MedicalSnippet({
    required this.id,
    required this.shortcut,
    required this.title,
    required this.content,
    this.category,
    this.isActive = true,
    this.createdAt,
    this.updatedAt,
  });

  MedicalSnippet copyWith({
    String? id,
    String? shortcut,
    String? title,
    String? content,
    String? category,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MedicalSnippet(
      id: id ?? this.id,
      shortcut: shortcut ?? this.shortcut,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'shortcut': shortcut,
      'title': title,
      'content': content,
      'category': category,
      'is_active': isActive,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  factory MedicalSnippet.fromJson(Map<String, dynamic> json) {
    return MedicalSnippet(
      id: json['id'] as String,
      shortcut: json['shortcut'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      category: json['category'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }
}
