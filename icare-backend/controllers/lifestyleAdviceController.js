const LifestyleAdvice = require('../models/LifestyleAdvice');
const { connectMongoDB } = require('../config/mongodb');
const EnhancedPrescription = require('../models/EnhancedPrescription');

// Lifestyle advice templates
const TEMPLATES = {
  diet: [
    {
      name: 'Diabetic Diet',
      recommendations: 'Follow a balanced diet with controlled carbohydrate intake',
      foodsToAvoid: ['Sugary drinks', 'White bread', 'Processed foods', 'Fried foods'],
      foodsToInclude: ['Whole grains', 'Vegetables', 'Lean proteins', 'Healthy fats'],
      mealTiming: 'Eat small frequent meals every 3-4 hours',
      hydration: 'Drink 8-10 glasses of water daily'
    },
    {
      name: 'Hypertension Diet',
      recommendations: 'Follow DASH diet with low sodium intake',
      foodsToAvoid: ['Salty foods', 'Processed meats', 'Canned foods', 'Fast food'],
      foodsToInclude: ['Fresh fruits', 'Vegetables', 'Low-fat dairy', 'Whole grains'],
      mealTiming: 'Regular meal times, avoid late night eating',
      hydration: 'Adequate water intake, limit caffeine'
    },
    {
      name: 'Weight Loss Diet',
      recommendations: 'Calorie-controlled balanced diet',
      foodsToAvoid: ['Sugary snacks', 'Fried foods', 'Processed foods', 'Sugary beverages'],
      foodsToInclude: ['Vegetables', 'Fruits', 'Lean proteins', 'Whole grains'],
      mealTiming: 'Eat breakfast, avoid late night snacking',
      hydration: 'Drink water before meals, 8-10 glasses daily'
    }
  ],
  exercise: [
    {
      name: 'General Fitness',
      type: 'Moderate aerobic exercise and strength training',
      frequency: '5 days per week',
      duration: '30-45 minutes per session',
      intensity: 'Moderate',
      precautions: ['Warm up before exercise', 'Cool down after', 'Stay hydrated']
    },
    {
      name: 'Cardiac Rehabilitation',
      type: 'Low to moderate intensity aerobic exercise',
      frequency: '3-5 days per week',
      duration: '20-30 minutes per session',
      intensity: 'Low to moderate',
      precautions: ['Start slowly', 'Monitor heart rate', 'Stop if chest pain occurs']
    },
    {
      name: 'Diabetes Management',
      type: 'Aerobic exercise and resistance training',
      frequency: '5 days per week',
      duration: '30 minutes per session',
      intensity: 'Moderate',
      precautions: ['Check blood sugar before and after', 'Carry glucose tablets', 'Wear proper footwear']
    }
  ],
  sleep: [
    {
      name: 'General Sleep Hygiene',
      recommendedHours: '7-9 hours',
      sleepSchedule: 'Consistent bedtime and wake time',
      sleepHygieneTips: [
        'Avoid screens 1 hour before bed',
        'Keep bedroom cool and dark',
        'Avoid caffeine after 2 PM',
        'Establish relaxing bedtime routine'
      ]
    },
    {
      name: 'Insomnia Management',
      recommendedHours: '7-8 hours',
      sleepSchedule: 'Fixed sleep and wake times',
      sleepHygieneTips: [
        'Use bed only for sleep',
        'Get up if unable to sleep after 20 minutes',
        'Avoid daytime napping',
        'Practice relaxation techniques'
      ]
    }
  ],
  stress: [
    {
      name: 'General Stress Management',
      techniques: [
        'Deep breathing exercises',
        'Meditation',
        'Progressive muscle relaxation',
        'Mindfulness'
      ],
      recommendations: 'Practice stress management techniques daily for 10-15 minutes'
    },
    {
      name: 'Work-Related Stress',
      techniques: [
        'Time management',
        'Setting boundaries',
        'Regular breaks',
        'Physical activity'
      ],
      recommendations: 'Take regular breaks, maintain work-life balance, seek support when needed'
    }
  ]
};

// Get lifestyle advice templates
exports.getTemplates = async (req, res) => {
  try {
    await connectMongoDB();
    res.json({
      success: true,
      templates: TEMPLATES
    });
  } catch (error) {
    console.error('Error getting templates:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get templates',
      error: error.message
    });
  }
};

// Create lifestyle advice
exports.createLifestyleAdvice = async (req, res) => {
  try {
    await connectMongoDB();
    const adviceData = req.body;

    // Validate required fields
    if (!adviceData.consultationId || !adviceData.prescriptionId) {
      return res.status(400).json({
        success: false,
        message: 'Consultation ID and Prescription ID are required'
      });
    }

    // Check if advice already exists
    let advice = await LifestyleAdvice.findOne({
      consultationId: adviceData.consultationId
    });

    if (advice) {
      // Update existing advice
      Object.assign(advice, adviceData);
      await advice.save();

      return res.json({
        success: true,
        adviceId: advice._id,
        advice,
        message: 'Lifestyle advice updated successfully'
      });
    }

    // Create new advice
    advice = new LifestyleAdvice(adviceData);
    await advice.save();

    // Update prescription with lifestyle advice reference
    const prescription = await EnhancedPrescription.findById(adviceData.prescriptionId);
    if (prescription) {
      prescription.lifestyleAdviceId = advice._id;
      await prescription.save();
    }

    res.json({
      success: true,
      adviceId: advice._id,
      advice,
      message: 'Lifestyle advice created successfully'
    });
  } catch (error) {
    console.error('Error creating lifestyle advice:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create lifestyle advice',
      error: error.message
    });
  }
};

// Get lifestyle advice by consultation ID
exports.getAdviceByConsultation = async (req, res) => {
  try {
    await connectMongoDB();
    const { consultationId } = req.params;

    const advice = await LifestyleAdvice.findOne({ consultationId });

    if (!advice) {
      return res.json({
        success: true,
        advice: null,
        message: 'No lifestyle advice found for this consultation'
      });
    }

    res.json({
      success: true,
      advice
    });
  } catch (error) {
    console.error('Error getting lifestyle advice:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get lifestyle advice',
      error: error.message
    });
  }
};

// Get lifestyle advice by prescription ID
exports.getAdviceByPrescription = async (req, res) => {
  try {
    await connectMongoDB();
    const { prescriptionId } = req.params;

    const advice = await LifestyleAdvice.findOne({ prescriptionId });

    if (!advice) {
      return res.json({
        success: true,
        advice: null,
        message: 'No lifestyle advice found for this prescription'
      });
    }

    res.json({
      success: true,
      advice
    });
  } catch (error) {
    console.error('Error getting lifestyle advice:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get lifestyle advice',
      error: error.message
    });
  }
};

// Update lifestyle advice
exports.updateLifestyleAdvice = async (req, res) => {
  try {
    await connectMongoDB();
    const { adviceId } = req.params;
    const updateData = req.body;

    const advice = await LifestyleAdvice.findById(adviceId);
    if (!advice) {
      return res.status(404).json({
        success: false,
        message: 'Lifestyle advice not found'
      });
    }

    // Update fields
    Object.assign(advice, updateData);
    await advice.save();

    res.json({
      success: true,
      advice,
      message: 'Lifestyle advice updated successfully'
    });
  } catch (error) {
    console.error('Error updating lifestyle advice:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update lifestyle advice',
      error: error.message
    });
  }
};

// Get lifestyle advice by ID
exports.getAdviceById = async (req, res) => {
  try {
    await connectMongoDB();
    const { adviceId } = req.params;

    const advice = await LifestyleAdvice.findById(adviceId);

    if (!advice) {
      return res.status(404).json({
        success: false,
        message: 'Lifestyle advice not found'
      });
    }

    res.json({
      success: true,
      advice
    });
  } catch (error) {
    console.error('Error getting lifestyle advice:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to get lifestyle advice',
      error: error.message
    });
  }
};
