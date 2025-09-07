interface RequiredEnvVars {
  APP_JWT_PUBLIC_PEM?: string;
  APP_JWT_PRIVATE_PEM?: string;
  APP_JWT_ISSUER?: string;
  MONGODB_URI?: string;
  DB_NAME?: string;
  PORT?: string;
  ALLOWED_ORIGINS?: string;
}

const requiredVars = [
  'APP_JWT_PUBLIC_PEM',
  'APP_JWT_PRIVATE_PEM',
  'APP_JWT_ISSUER',
  'MONGODB_URI'
] as const;

const optionalVars: Partial<RequiredEnvVars> = {
  DB_NAME: 'expense_tracker',
  PORT: '3000',
  ALLOWED_ORIGINS: ''
};

export function validateEnvironment(): void {
  const missing: string[] = [];
  
  for (const varName of requiredVars) {
    if (!process.env[varName]) {
      missing.push(varName);
    }
  }
  
  if (missing.length > 0) {
    console.error('❌ Missing required environment variables:');
    missing.forEach(var_name => {
      console.error(`  - ${var_name}`);
    });
    console.error('\nPlease check your .env file or environment configuration.');
    process.exit(1);
  }
  
  // Set defaults for optional variables
  for (const [key, defaultValue] of Object.entries(optionalVars)) {
    if (!process.env[key]) {
      process.env[key] = defaultValue;
    }
  }
  
  console.log('✅ Environment validation passed');
}
