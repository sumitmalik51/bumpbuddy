/// Curated, offline pregnancy FAQ — general educational answers, never
/// diagnostic. Every clinical answer defers to the treating doctor. Bundled
/// (no network, no database, no moderation needed).
class FaqItem {
  final String category;
  final String question;
  final String answer;
  const FaqItem(this.category, this.question, this.answer);
}

const List<FaqItem> kFaq = [
  // Early pregnancy
  FaqItem('Early pregnancy', 'How is my due date calculated?',
      'The estimated due date (EDD) is usually counted as 280 days (40 weeks) from the first day of your last menstrual period, or set from an early dating scan. Only about 1 in 20 babies actually arrives on the exact date — a window around it is normal.'),
  FaqItem('Early pregnancy', 'Is some spotting normal in early pregnancy?',
      'Light spotting can happen and is often harmless, but bleeding in pregnancy should always be mentioned to your doctor the same day — especially if it is heavy, bright red, or comes with pain. When in doubt, call your care team.'),
  FaqItem('Early pregnancy', 'What supplements are usually advised?',
      'Folic acid (typically started before or in early pregnancy), and often iron, calcium and vitamin D as your doctor prescribes. Never start or stop a supplement without checking with your doctor — this app does not give dosing advice.'),

  // Nutrition
  FaqItem('Nutrition', 'What foods should I usually avoid?',
      'Commonly advised to avoid: raw or undercooked meat/eggs, unpasteurised dairy, high-mercury fish, excess caffeine, and alcohol entirely. Wash fruits and vegetables well. Your doctor may add to this based on your health.'),
  FaqItem('Nutrition', 'Can I eat papaya / pineapple?',
      'Ripe papaya and pineapple in normal food amounts are generally considered fine; raw/unripe papaya is traditionally avoided by many. Advice varies by region and person — check with your own doctor if you are unsure.'),
  FaqItem('Nutrition', 'How much extra should I eat, especially with twins?',
      'Pregnancy needs modestly more energy and protein — it is quality, not "eating for two/three". Twin pregnancies do have higher calorie, protein and iron needs; your doctor or a dietitian will guide the right targets for you.'),

  // Symptoms
  FaqItem('Symptoms', 'How do I manage nausea and vomiting?',
      'Small frequent meals, staying hydrated, ginger, and avoiding trigger smells help many people. If you cannot keep fluids down, are losing weight, or feel faint, contact your doctor — it may need treatment.'),
  FaqItem('Symptoms', 'Is back pain and swelling normal?',
      'Mild back pain and some foot/ankle swelling are common, especially later on. But sudden or severe swelling of the face/hands, a bad headache, or vision changes can signal high blood pressure — contact your care team the same day.'),
  FaqItem('Symptoms', 'When should I worry about reduced baby movements?',
      'From around 28 weeks, get to know your baby\'s usual pattern. If movements clearly reduce or stop, contact your maternity unit the same day — do not wait until tomorrow. For twins this matters for each baby.'),

  // Tests & scans
  FaqItem('Tests & scans', 'What is the anomaly (TIFFA) scan?',
      'A detailed scan usually done at 18–22 weeks that checks the baby\'s structure — brain, heart, spine, limbs — and the placenta and fluid. For twins, each baby is checked.'),
  FaqItem('Tests & scans', 'What is the OGTT / sugar test?',
      'The oral glucose tolerance test screens for gestational diabetes, usually around 24–28 weeks. Twin pregnancies have a higher chance of gestational diabetes, so it is important not to skip it.'),
  FaqItem('Tests & scans', 'What do EFW and AFI mean on my scan?',
      'EFW is the estimated fetal weight (in grams) the scan calculates from measurements like head, abdomen and femur. AFI (or DVP/MVP) describes the amount of amniotic fluid. Your doctor reads these together with growth trends — a single number rarely tells the whole story.'),
  FaqItem('Tests & scans', 'What is a normal fetal heart rate?',
      'A fetal heart rate in roughly the 110–160 bpm range is commonly seen, and it varies with the baby\'s activity. Your scan report will note it; your doctor interprets whether it is appropriate for your stage.'),

  // Twins
  FaqItem('Twins', 'What does chorionicity (DCDA/MCDA/MCMA) mean?',
      'It describes whether your twins share a placenta and/or sac. DCDA (di-di) each have their own; MCDA (mo-di) share a placenta; MCMA (mo-mo) share both. It is set early by a first-trimester scan and decides how closely you are monitored and typical delivery timing.'),
  FaqItem('Twins', 'Why are shared-placenta twins scanned more often?',
      'Twins who share a placenta (MCDA/MCMA) are usually scanned about every 2 weeks from ~16 weeks to watch for twin-to-twin transfusion (TTTS) and growth differences. Di-di twins are typically scanned less often. Your team sets your exact schedule.'),
  FaqItem('Twins', 'What is "growth discordance" between twins?',
      'It is the difference in estimated weight between the two babies, as a percentage of the larger one. Doctors usually take a closer look at differences around 20% or more. The app flags this on your growth screen, but interpretation is your doctor\'s.'),
  FaqItem('Twins', 'When are twins usually born?',
      'Uncomplicated di-di (DCDA) twins are often delivered around 37–38 weeks, mo-di (MCDA) around 36–37, and mo-mo (MCMA) earlier (about 32–34) with intensive monitoring. Your own plan depends on your pregnancy — your doctor decides.'),

  // Labour & birth
  FaqItem('Labour & birth', 'What is the 5-1-1 rule for contractions?',
      'A common full-term guide: contractions about every 5 minutes, each lasting about 1 minute, continuing for about 1 hour. Your doctor may give you a different plan (often earlier for twins). When unsure, call — the app\'s contraction timer watches for this pattern.'),
  FaqItem('Labour & birth', 'What should be in my hospital bag?',
      'Documents, comfortable clothes and toiletries for you, baby clothes/nappies/swaddles, and items for your partner. For twins, pack extra baby items, preemie sizes, and two car seats — and pack earlier, since twins often arrive before 38 weeks. See the app\'s Hospital bag checklist.'),
  FaqItem('Labour & birth', 'When should I go to the hospital?',
      'Go in (or call) for regular painful contractions per your doctor\'s guidance, waters breaking, any bleeding, reduced baby movements, severe headache or vision changes, or if something just feels wrong. Trust your instinct — it is always okay to call.'),

  // Wellbeing
  FaqItem('Wellbeing', 'Is it safe to exercise during pregnancy?',
      'Gentle activity like walking, prenatal yoga or swimming is usually encouraged in an uncomplicated pregnancy, but twin and high-risk pregnancies sometimes need more caution. Check what is right for you with your doctor before starting.'),
  FaqItem('Wellbeing', 'What is the best sleeping position?',
      'From the second half of pregnancy, sleeping on your side (either side) is generally advised over flat on your back, as it helps blood flow. A pillow between the knees or under the bump can help comfort.'),
  FaqItem('Wellbeing', 'How do I look after my mental health?',
      'Mood ups and downs are common, but persistent sadness, anxiety or feeling unable to cope deserve attention — talk to your doctor. Rest, support from people you trust, and asking for help early all matter, and twin parents especially should line up help for the early days.'),
];

List<String> get faqCategories {
  final seen = <String>[];
  for (final f in kFaq) {
    if (!seen.contains(f.category)) seen.add(f.category);
  }
  return seen;
}
