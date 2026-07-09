const pool = require('../config/database');

const createTables = async () => {
  try {
    await pool.query(`
      -- Users table (all roles)
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        username VARCHAR(100) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        phone VARCHAR(20),
        password VARCHAR(255) NOT NULL,
        role VARCHAR(50) NOT NULL CHECK (role IN ('patient', 'doctor', 'lab', 'pharmacy', 'instructor', 'student', 'admin')),
        is_approved BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- User profiles
      CREATE TABLE IF NOT EXISTS user_profiles (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        full_name VARCHAR(255),
        date_of_birth DATE,
        gender VARCHAR(20),
        address TEXT,
        city VARCHAR(100),
        country VARCHAR(100),
        profile_image TEXT,
        bio TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Doctor profiles
      CREATE TABLE IF NOT EXISTS doctor_profiles (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        specialization VARCHAR(255),
        license_number VARCHAR(100) UNIQUE,
        experience_years INTEGER,
        consultation_fee DECIMAL(10,2),
        available_days TEXT[],
        available_hours TEXT,
        rating DECIMAL(3,2) DEFAULT 0.0,
        total_reviews INTEGER DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Lab profiles
      CREATE TABLE IF NOT EXISTS lab_profiles (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        lab_name VARCHAR(255) NOT NULL,
        license_number VARCHAR(100) UNIQUE,
        accreditation TEXT,
        services TEXT[],
        operating_hours TEXT,
        address TEXT,
        city VARCHAR(100),
        drap_compliance BOOLEAN DEFAULT false,
        rating DECIMAL(3,2) DEFAULT 0.0,
        total_reviews INTEGER DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Pharmacy profiles
      CREATE TABLE IF NOT EXISTS pharmacy_profiles (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        pharmacy_name VARCHAR(255) NOT NULL,
        license_number VARCHAR(100) UNIQUE,
        operating_hours TEXT,
        delivery_available BOOLEAN DEFAULT false,
        address TEXT,
        city VARCHAR(100),
        drap_compliance BOOLEAN DEFAULT false,
        rating DECIMAL(3,2) DEFAULT 0.0,
        total_reviews INTEGER DEFAULT 0,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Products (medicines and health items)
      CREATE TABLE IF NOT EXISTS products (
        id SERIAL PRIMARY KEY,
        pharmacy_id INTEGER REFERENCES users(id),
        name VARCHAR(255) NOT NULL,
        generic_name VARCHAR(255),
        description TEXT,
        category VARCHAR(100),
        medicine_category VARCHAR(50) DEFAULT 'OTC' CHECK (medicine_category IN ('OTC', 'Controlled', 'Vaccine')),
        price DECIMAL(10,2) NOT NULL,
        stock_quantity INTEGER DEFAULT 0,
        image_url TEXT,
        manufacturer VARCHAR(255),
        requires_prescription BOOLEAN DEFAULT false,
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Appointments
      CREATE TABLE IF NOT EXISTS appointments (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES users(id),
        doctor_id INTEGER REFERENCES users(id),
        appointment_date DATE NOT NULL,
        appointment_time TIME NOT NULL,
        status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'completed', 'cancelled')),
        consultation_type VARCHAR(50) CHECK (consultation_type IN ('video', 'in-person', 'chat')),
        notes TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Medical records
      CREATE TABLE IF NOT EXISTS medical_records (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES users(id),
        doctor_id INTEGER REFERENCES users(id),
        record_type VARCHAR(100),
        title VARCHAR(255) NOT NULL,
        description TEXT,
        file_url TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Lab test requests
      CREATE TABLE IF NOT EXISTS lab_test_requests (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES users(id),
        lab_id INTEGER REFERENCES users(id),
        test_type VARCHAR(255) NOT NULL,
        status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'in-progress', 'completed', 'cancelled')),
        test_date DATE,
        results TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Prescriptions
      CREATE TABLE IF NOT EXISTS prescriptions (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES users(id),
        doctor_id INTEGER REFERENCES users(id),
        appointment_id INTEGER REFERENCES appointments(id),
        prescription_date DATE DEFAULT CURRENT_DATE,
        medications JSONB,
        instructions TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Pharmacy orders
      CREATE TABLE IF NOT EXISTS pharmacy_orders (
        id SERIAL PRIMARY KEY,
        patient_id INTEGER REFERENCES users(id),
        pharmacy_id INTEGER REFERENCES users(id),
        prescription_id INTEGER REFERENCES prescriptions(id),
        status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'confirmed', 'preparing', 'out-for-delivery', 'delivered', 'cancelled')),
        total_amount DECIMAL(10,2),
        delivery_fee DECIMAL(10,2) DEFAULT 0,
        delivery_address TEXT,
        expected_delivery_time TEXT,
        order_number VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Ratings & Reviews
      CREATE TABLE IF NOT EXISTS ratings (
        id SERIAL PRIMARY KEY,
        reviewer_id INTEGER REFERENCES users(id),
        target_id INTEGER REFERENCES users(id),
        target_type VARCHAR(50) CHECK (target_type IN ('doctor', 'pharmacy', 'lab')),
        reference_id INTEGER,
        reference_type VARCHAR(50),
        rating INTEGER CHECK (rating BETWEEN 1 AND 5),
        comment TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Order items (products in each order)
      CREATE TABLE IF NOT EXISTS order_items (
        id SERIAL PRIMARY KEY,
        order_id INTEGER REFERENCES pharmacy_orders(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id),
        quantity INTEGER NOT NULL,
        price DECIMAL(10,2) NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Shopping cart
      CREATE TABLE IF NOT EXISTS cart_items (
        id SERIAL PRIMARY KEY,
        user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
        product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
        quantity INTEGER NOT NULL DEFAULT 1,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(user_id, product_id)
      );

      -- Courses (LMS)
      CREATE TABLE IF NOT EXISTS courses (
        id SERIAL PRIMARY KEY,
        instructor_id INTEGER REFERENCES users(id),
        title VARCHAR(255) NOT NULL,
        description TEXT,
        category VARCHAR(100),
        duration VARCHAR(100),
        price DECIMAL(10,2) DEFAULT 0,
        thumbnail_url TEXT,
        video_url TEXT,
        is_published BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Course enrollments
      CREATE TABLE IF NOT EXISTS course_enrollments (
        id SERIAL PRIMARY KEY,
        course_id INTEGER REFERENCES courses(id) ON DELETE CASCADE,
        student_id INTEGER REFERENCES users(id),
        enrolled_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        progress INTEGER DEFAULT 0,
        completed BOOLEAN DEFAULT false,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );

      -- Create indexes for better performance
      CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
      CREATE INDEX IF NOT EXISTS idx_users_role ON users(role);
      CREATE INDEX IF NOT EXISTS idx_appointments_patient ON appointments(patient_id);
      CREATE INDEX IF NOT EXISTS idx_appointments_doctor ON appointments(doctor_id);
      CREATE INDEX IF NOT EXISTS idx_lab_requests_patient ON lab_test_requests(patient_id);
      CREATE INDEX IF NOT EXISTS idx_prescriptions_patient ON prescriptions(patient_id);
    `);

    console.log('✅ Database tables created successfully');
  } catch (error) {
    console.error('❌ Error creating tables:', error);
    throw error;
  }
};

module.exports = { createTables };
