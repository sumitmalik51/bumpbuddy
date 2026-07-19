/// Educational week-by-week content (weeks 4–40).
/// Sizes/weights are population averages for singletons — twins commonly track
/// slightly smaller in the third trimester, which is expected and monitored.
class WeekInfo {
  final int week;
  final String size; // fruit/veg comparison
  final String approx; // approximate length & weight
  final String development;
  final List<String> tips;

  const WeekInfo({
    required this.week,
    required this.size,
    required this.approx,
    required this.development,
    required this.tips,
  });
}

class WeeklyContent {
  static WeekInfo forWeek(int week) {
    final w = week.clamp(4, 40);
    return _weeks.firstWhere((e) => e.week == w);
  }

  /// Playful fruit/veg emoji matching each week's size comparison.
  static String emojiForWeek(int week) => switch (week.clamp(4, 40)) {
        <= 6 => '🌱',
        7 => '🫐',
        8 => '🫘',
        9 => '🍇',
        10 => '🍊',
        11 => '🍐',
        12 => '🍋',
        13 => '🫛',
        14 => '🍋',
        15 => '🍎',
        16 => '🥑',
        17 => '🥔',
        18 => '🫑',
        19 => '🍅',
        20 => '🍌',
        21 => '🥕',
        22 => '🍈',
        23 => '🥭',
        24 => '🌽',
        25 => '🥦',
        26 => '🥒',
        27 => '🥦',
        28 => '🍆',
        29 => '🍠',
        30 => '🥬',
        31 => '🥥',
        32 => '🍠',
        33 => '🍍',
        34 => '🍈',
        35 => '🍈',
        36 => '🥬',
        37 => '🍈',
        38 => '🎃',
        39 => '🍉',
        _ => '🍉',
      };

  static const List<WeekInfo> _weeks = [
    WeekInfo(
        week: 4,
        size: 'Poppy seed',
        approx: '~1 mm',
        development:
            'The embryo has implanted and the neural tube — the future brain and spine — is beginning to form.',
        tips: ['Start (or continue) folic acid daily.', 'Avoid alcohol and smoking completely.']),
    WeekInfo(
        week: 5,
        size: 'Sesame seed',
        approx: '~2 mm',
        development: 'The tiny heart begins to beat and major organs start forming.',
        tips: ['Book your first prenatal appointment.', 'Check any regular medicines with your doctor.']),
    WeekInfo(
        week: 6,
        size: 'Lentil',
        approx: '~5 mm',
        development:
            'The heartbeat may be visible on an early scan. Facial features begin to take shape.',
        tips: ['Small frequent meals help with nausea.', 'Stay hydrated — aim for 8–10 glasses a day.']),
    WeekInfo(
        week: 7,
        size: 'Blueberry',
        approx: '~1 cm',
        development: 'The brain is growing rapidly and little limb buds appear.',
        tips: ['A dating scan around now confirms due date — and how many babies!']),
    WeekInfo(
        week: 8,
        size: 'Kidney bean',
        approx: '~1.6 cm · 1 g',
        development: 'Fingers and toes are forming; the embryo starts tiny movements.',
        tips: ['First blood panel is usually done around now (CBC, blood group, thyroid, sugar).']),
    WeekInfo(
        week: 9,
        size: 'Grape',
        approx: '~2.3 cm · 2 g',
        development: 'All essential organs have begun forming; the tail is gone.',
        tips: ['Fatigue is very common — rest when you can.']),
    WeekInfo(
        week: 10,
        size: 'Kumquat',
        approx: '~3 cm · 4 g',
        development: 'Officially a fetus now. Vital organs are formed and starting to function.',
        tips: ['Gentle exercise like walking is great, unless advised otherwise.']),
    WeekInfo(
        week: 11,
        size: 'Fig',
        approx: '~4 cm · 7 g',
        development: 'Baby can open and close fists; bones are hardening.',
        tips: ['NT scan window opens (11–13.6 weeks) — schedule it if not booked.']),
    WeekInfo(
        week: 12,
        size: 'Lime',
        approx: '~5.5 cm · 14 g',
        development: 'Reflexes are developing; kidneys begin producing urine.',
        tips: ['Dual marker blood test usually pairs with the NT scan.']),
    WeekInfo(
        week: 13,
        size: 'Pea pod',
        approx: '~7.5 cm · 23 g',
        development: 'Vocal cords form. Welcome to the edge of the second trimester!',
        tips: ['Nausea often eases from here.', 'Add protein: dal, paneer, eggs, curd.']),
    WeekInfo(
        week: 14,
        size: 'Lemon',
        approx: '~8.5 cm · 43 g',
        development: 'Baby can squint and frown; fine hair (lanugo) grows.',
        tips: ['Second trimester — usually the most comfortable one. Plan gentle activity.']),
    WeekInfo(
        week: 15,
        size: 'Apple',
        approx: '~10 cm · 70 g',
        development: 'Baby senses light through closed eyelids; the skeleton is hardening.',
        tips: ['Calcium and vitamin D matter now — keep up supplements as prescribed.']),
    WeekInfo(
        week: 16,
        size: 'Avocado',
        approx: '~12 cm · 100 g',
        development: 'Growth spurt underway. First flutters (quickening) may be felt soon.',
        tips: ['If a quad-marker test is advised, it happens around now.']),
    WeekInfo(
        week: 17,
        size: 'Turnip',
        approx: '~13 cm · 140 g',
        development: 'Fat stores begin forming under the skin.',
        tips: ['Sleep on your side when comfortable; a pillow between the knees helps.']),
    WeekInfo(
        week: 18,
        size: 'Bell pepper',
        approx: '~14 cm · 190 g',
        development: 'Ears reach their final position — baby may begin to hear you.',
        tips: ['Anomaly scan (TIFFA) window opens: 18–22 weeks.']),
    WeekInfo(
        week: 19,
        size: 'Tomato',
        approx: '~15 cm · 240 g',
        development: 'A protective coating (vernix) covers the skin.',
        tips: ['Talk or sing to the bump — hearing is developing.']),
    WeekInfo(
        week: 20,
        size: 'Banana',
        approx: '~25 cm · 300 g',
        development: 'Halfway there! Baby swallows more and produces meconium.',
        tips: ['The anomaly scan checks heart, brain, spine, limbs and placenta in detail.']),
    WeekInfo(
        week: 21,
        size: 'Carrot',
        approx: '~27 cm · 360 g',
        development: 'Movements turn from flutters into proper kicks.',
        tips: ['Iron-rich food helps: greens, jaggery, dates, beetroot.']),
    WeekInfo(
        week: 22,
        size: 'Papaya (small)',
        approx: '~28 cm · 430 g',
        development: 'Eyebrows and eyelids are fully formed; grip reflex develops.',
        tips: ['Note down questions for your next visit — this app has a journal for that.']),
    WeekInfo(
        week: 23,
        size: 'Large mango',
        approx: '~29 cm · 500 g',
        development: 'Hearing sharpens; baby may respond to loud sounds.',
        tips: ['Watch for swelling in feet — mention sudden swelling to your doctor.']),
    WeekInfo(
        week: 24,
        size: 'Corn (ear)',
        approx: '~30 cm · 600 g',
        development: 'A big milestone week: lungs begin producing surfactant.',
        tips: ['Glucose test (OGTT) window: 24–28 weeks.']),
    WeekInfo(
        week: 25,
        size: 'Cauliflower (small)',
        approx: '~34 cm · 660 g',
        development: 'Baby startles at sounds and develops sleep-wake patterns.',
        tips: ['Practice left-side sleeping; it improves blood flow to the placenta.']),
    WeekInfo(
        week: 26,
        size: 'Cucumber',
        approx: '~35 cm · 760 g',
        development: 'Eyes begin to open; brain activity for sight and sound increases.',
        tips: ['If OGTT is pending, get it done this window.']),
    WeekInfo(
        week: 27,
        size: 'Cauliflower',
        approx: '~36 cm · 875 g',
        development: 'Third trimester begins. Baby has sleep cycles — and maybe dreams.',
        tips: ['Tdap vaccine window opens (27–36 weeks).']),
    WeekInfo(
        week: 28,
        size: 'Eggplant (large)',
        approx: '~37 cm · 1 kg',
        development: 'Eyes can blink and sense light changes.',
        tips: ['If you are Rh-negative, the anti-D injection is usually given now.',
          'Start paying attention to daily movement patterns.']),
    WeekInfo(
        week: 29,
        size: 'Butternut squash',
        approx: '~38 cm · 1.2 kg',
        development: 'Bones are fully formed but still soft; kicks get stronger.',
        tips: ['Track movements daily — tell your doctor the same day if they reduce.']),
    WeekInfo(
        week: 30,
        size: 'Cabbage',
        approx: '~40 cm · 1.3 kg',
        development: 'The brain grows rapidly; baby can regulate some body temperature.',
        tips: ['Growth scan window (28–32 weeks) for most pregnancies.']),
    WeekInfo(
        week: 31,
        size: 'Coconut',
        approx: '~41 cm · 1.5 kg',
        development: 'All five senses are working now.',
        tips: ['Shortness of breath is common — rest, and report chest pain immediately.']),
    WeekInfo(
        week: 32,
        size: 'Jicama / yam',
        approx: '~42 cm · 1.7 kg',
        development: 'Baby practices breathing movements and usually settles head-down.',
        tips: ['Start thinking about the hospital bag — the checklist here adapts for twins.']),
    WeekInfo(
        week: 33,
        size: 'Pineapple',
        approx: '~44 cm · 1.9 kg',
        development: 'The immune system is developing; the skull stays soft for birth.',
        tips: ['Discuss birth preferences with your doctor.']),
    WeekInfo(
        week: 34,
        size: 'Cantaloupe',
        approx: '~45 cm · 2.1 kg',
        development: 'Fingernails reach the fingertips; most organs are nearly mature.',
        tips: ['Pack the hospital bag if twins are on board — twin arrivals come earlier.']),
    WeekInfo(
        week: 35,
        size: 'Honeydew melon',
        approx: '~46 cm · 2.4 kg',
        development: 'Kidneys are fully developed; baby gains roughly 200 g a week.',
        tips: ['Confirm hospital admission process and emergency numbers.']),
    WeekInfo(
        week: 36,
        size: 'Romaine lettuce',
        approx: '~47 cm · 2.6 kg',
        development: 'Baby is shedding vernix and lanugo; checkups usually go weekly now.',
        tips: ['Install the car seat(s) and do a trial run to the hospital.']),
    WeekInfo(
        week: 37,
        size: 'Winter melon',
        approx: '~48 cm · 2.9 kg',
        development: 'Early term. Lungs are nearly ready for the outside world.',
        tips: ['Rest, hydrate, and keep the phone charged.']),
    WeekInfo(
        week: 38,
        size: 'Pumpkin (small)',
        approx: '~49 cm · 3.0 kg',
        development: 'The brain is still adding connections at full speed.',
        tips: ['Know the signs of labour: regular tightenings, water breaking, show.']),
    WeekInfo(
        week: 39,
        size: 'Mini watermelon',
        approx: '~50 cm · 3.3 kg',
        development: 'Full term! Baby is simply gaining strength now.',
        tips: ['Any decrease in movements still matters — call your doctor the same day.']),
    WeekInfo(
        week: 40,
        size: 'Watermelon (small)',
        approx: '~51 cm · 3.4 kg',
        development: 'Due date week. Only about 5% of babies arrive exactly on it.',
        tips: ['Your doctor will discuss monitoring or induction if baby stays put.']),
  ];

  /// Red-flag symptoms that always warrant a same-day call to the doctor.
  static const List<String> warningSigns = [
    'Vaginal bleeding or fluid leaking',
    'Severe or persistent headache, blurred vision, or sudden swelling of face/hands',
    'Reduced or absent baby movements (after ~28 weeks)',
    'Fever above 100.4°F / 38°C',
    'Severe abdominal pain or regular tightenings before 37 weeks',
    'Burning urination or very reduced urine output',
    'Persistent vomiting and inability to keep fluids down',
  ];
}
