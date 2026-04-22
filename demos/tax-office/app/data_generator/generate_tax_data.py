#
# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
#!/usr/bin/env python3
"""
Tax Office Data Generator
Generates realistic dummy data for the tax_office.all_data table
Supports both TRAINING and NEW_FILING data types
"""

import pandas as pd
import numpy as np
import random
from datetime import datetime, date, timedelta
from typing import Dict
import argparse

class TaxDataGenerator:
  def __init__(self, seed=42):
    random.seed(seed)
    np.random.seed(seed)

    # Regional administrative divisions
    self.regions = [
      'Region_A', 'Region_B', 'Region_C', 'Region_D', 'Region_E',
      'Region_F', 'Region_G', 'Region_H', 'Region_I', 'Region_J',
      'Region_K', 'Region_L', 'Region_M', 'Region_N', 'Region_O',
      'Region_P'
    ]

    # Common industry codes
    self.industry_codes = [
      '4711', '6201', '7022', '8520', '9609', '4618', '6820', '7111',
      '8560', '9003', '4751', '6910', '7112', '8610', '9319'
    ]

    # Crypto exchanges
    self.crypto_exchanges = [
      'Binance', 'Coinbase', 'Kraken', 'Bitstamp', 'Bitpanda',
      'eToro', 'Bison', 'Trade Republic'
    ]

    # Generic first names
    self.first_names = [
      'Person_A', 'Person_B', 'Person_C', 'Person_D', 'Person_E',
      'Person_F', 'Person_G', 'Person_H', 'Person_I', 'Person_J',
      'Person_K', 'Person_L', 'Person_M', 'Person_N', 'Person_O',
      'Person_P', 'Person_Q', 'Person_R', 'Person_S', 'Person_T'
    ]

    # Generic last names
    self.last_names = [
      'Lastname_01', 'Lastname_02', 'Lastname_03', 'Lastname_04',
      'Lastname_05', 'Lastname_06', 'Lastname_07', 'Lastname_08',
      'Lastname_09', 'Lastname_10', 'Lastname_11', 'Lastname_12',
      'Lastname_13', 'Lastname_14', 'Lastname_15', 'Lastname_16',
      'Lastname_17', 'Lastname_18', 'Lastname_19', 'Lastname_20'
    ]

    # Generic company names
    self.company_names = [
      'Company_Alpha_Ltd', 'Company_Beta_GmbH', 'Company_Gamma_AG',
      'Company_Delta_Ltd', 'Company_Epsilon_GmbH', 'Company_Zeta_AG',
      'Company_Eta_Ltd', 'Company_Theta_GmbH', 'Company_Iota_AG',
      'Company_Kappa_Ltd', 'Company_Lambda_GmbH', 'Company_Mu_AG',
      'Company_Nu_Ltd', 'Company_Xi_GmbH', 'Company_Omicron_AG'
    ]

  def generate_taxpayer_id(self, prefix: str = 'TP') -> str:
    """Generate unique taxpayer ID"""
    return f"{prefix}_{random.randint(100000, 999999)}"

  def generate_declaration_id(self, taxpayer_id: str, year: int, has_crypto: bool = False) -> str:
    """Generate declaration ID based on taxpayer and year"""
    prefix = "DECL_CRYP" if has_crypto else "DECL"
    return f"{prefix}_{taxpayer_id}_{year}_{random.randint(1000, 9999)}"

  def calculate_derived_fields(self, row: Dict) -> Dict:
    """Calculate derived fields based on base financial data"""
    # Calculate ratios
    if row['gross_income'] > 0:
      row['deduction_ratio'] = row['total_deductions'] / row['gross_income']
      row['crypto_income_ratio'] = row['declared_crypto_income'] / row['gross_income']
    else:
      row['deduction_ratio'] = 0
      row['crypto_income_ratio'] = 0

    if row['taxable_income'] > 0:
      row['tax_ratio'] = row['calculated_tax'] / row['taxable_income']
    else:
      row['tax_ratio'] = 0

    # Crypto non-declarant flag
    row['is_crypto_non_declarant'] = (
        row['has_crypto_account'] and row['declared_crypto_income'] == 0
    )

    # Crypto risk score (0-1)
    risk_factors = 0
    if row['is_crypto_non_declarant']:
      risk_factors += 0.4
    if row['crypto_transaction_count'] > 100:
      risk_factors += 0.3
    if not row['has_declared_crypto_previously'] and row['has_crypto_account']:
      risk_factors += 0.2
    if row['deduction_ratio'] > 0.5:
      risk_factors += 0.1

    row['crypto_risk_score'] = min(1.0, risk_factors)

    return row

  def determine_anomaly(self, row: Dict) -> Dict:
    """Determine if this record should be marked as anomaly"""
    anomaly_score = 0
    anomaly_reasons = []

    # High deduction ratio - increased weight for non-crypto anomalies
    if row['deduction_ratio'] > 0.6:
      anomaly_score += 0.4
      anomaly_reasons.append('HIGH_DEDUCTIONS')
    elif row['deduction_ratio'] > 0.5:
      anomaly_score += 0.25
      anomaly_reasons.append('ELEVATED_DEDUCTIONS')

    # Crypto evasion - reduced weight to balance with other anomalies
    if row['is_crypto_non_declarant'] and row['crypto_transaction_count'] > 50:
      anomaly_score += 0.35
      anomaly_reasons.append('CRYPTO_EVASION')

    # Late filing pattern - increased weight
    if row['late_filing_rate'] > 0.5:
      anomaly_score += 0.3
      anomaly_reasons.append('CHRONIC_LATE_FILING')
    elif row['late_filing_rate'] > 0.3:
      anomaly_score += 0.2
      anomaly_reasons.append('LATE_PATTERN')

    # Suspicious payment delays - increased weight
    if row['days_payment_delay'] > 120:
      anomaly_score += 0.3
      anomaly_reasons.append('SEVERE_PAYMENT_DELAY')
    elif row['days_payment_delay'] > 90:
      anomaly_score += 0.2
      anomaly_reasons.append('PAYMENT_DELAY')

    # Late payment pattern - new check
    if row['late_payment_rate'] > 0.4:
      anomaly_score += 0.25
      anomaly_reasons.append('CHRONIC_LATE_PAYMENT')

    # High income volatility with suspicious deductions
    if row['income_volatility'] > 0.7 and row['deduction_ratio'] > 0.4:
      anomaly_score += 0.2
      anomaly_reasons.append('INCOME_VOLATILITY_WITH_HIGH_DEDUCTIONS')
    elif row['income_volatility'] > 0.8:
      anomaly_score += 0.15
      anomaly_reasons.append('INCOME_VOLATILITY')

    # Frequent amendments - new check
    if row['amendment_rate'] > 0.3:
      anomaly_score += 0.2
      anomaly_reasons.append('FREQUENT_AMENDMENTS')

    # Determine if anomaly (threshold: 0.4)
    row['is_anomaly'] = anomaly_score >= 0.4
    row['anomaly_confidence'] = min(1.0, anomaly_score)
    row['anomaly_type'] = ','.join(anomaly_reasons) if anomaly_reasons else None

    return row

  def generate_individual_record(self, year: int, data_source: str, force_non_crypto_anomaly: bool = False) -> Dict:
    """Generate a single individual taxpayer record"""
    taxpayer_id = self.generate_taxpayer_id('IND')

    # Base income (realistic individual income distribution)
    income_bracket = random.choices(
      ['low', 'medium', 'high', 'very_high'],
      weights=[40, 35, 20, 5]
    )[0]

    if income_bracket == 'low':
      gross_income = random.uniform(15000, 35000)
    elif income_bracket == 'medium':
      gross_income = random.uniform(35000, 65000)
    elif income_bracket == 'high':
      gross_income = random.uniform(65000, 120000)
    else:  # very_high
      gross_income = random.uniform(120000, 500000)

    # Deductions (typically 10-30% for individuals, some outliers)
    # Force high deductions if creating intentional non-crypto anomaly
    if force_non_crypto_anomaly:
      deduction_pct = random.uniform(0.6, 0.8)
    elif random.random() < 0.08:  # 8% have suspiciously high deductions
      deduction_pct = random.uniform(0.6, 0.8)
    elif random.random() < 0.15:  # 15% have elevated deductions
      deduction_pct = random.uniform(0.5, 0.6)
    else:
      deduction_pct = random.uniform(0.1, 0.3)

    total_deductions = gross_income * deduction_pct
    taxable_income = max(0, gross_income - total_deductions)

    # Progressive tax calculation (simplified)
    if taxable_income <= 9984:
      calculated_tax = 0
    elif taxable_income <= 58596:
      calculated_tax = taxable_income * 0.14
    else:
      calculated_tax = taxable_income * 0.42

    # Crypto data - realistic percentages based on data source
    if data_source == 'TRAINING':
      # Training data: 15% have crypto (historical data)
      crypto_probability = 0.15
    else:
      # NEW_FILING: 5% have crypto (more realistic for general population)
      crypto_probability = 0.05

    has_crypto = random.random() < crypto_probability
    crypto_income = 0
    crypto_transactions = 0
    crypto_exchange = None
    crypto_verified_date = None
    has_declared_crypto_prev = False

    if has_crypto:
      crypto_exchange = random.choice(self.crypto_exchanges)
      crypto_verified_date = date(year - random.randint(0, 3),
                                  random.randint(1, 12),
                                  random.randint(1, 28))
      crypto_transactions = random.randint(5, 500)
      has_declared_crypto_prev = random.random() < 0.6

      # 30% of crypto holders don't declare income (suspicious)
      if random.random() < 0.7:
        crypto_income = random.uniform(100, gross_income * 0.2)

    # Filing behavior
    filing_date = date(year + 1, random.randint(1, 12), random.randint(1, 28))
    is_late_filing = filing_date > date(year + 1, 5, 31)
    days_filing_delay = max(0, (filing_date - date(year + 1, 5, 31)).days)

    # Payment behavior - more variation to create anomalies
    if random.random() < 0.12:  # 12% have severe payment delays
      payment_date = filing_date + timedelta(days=random.randint(120, 180))
    else:
      payment_date = filing_date + timedelta(days=random.randint(0, 120))
    is_late_payment = payment_date > filing_date + timedelta(days=30)
    days_payment_delay = max(0, (payment_date - filing_date - timedelta(days=30)).days)

    # Historical patterns (simulate past behavior with more anomalies)
    # Force problematic patterns if creating intentional non-crypto anomaly
    if force_non_crypto_anomaly:
      # Create a combination of issues
      late_filing_rate = random.uniform(0.5, 0.8)
      late_payment_rate = random.uniform(0.4, 0.7)
      amendment_rate = random.uniform(0.3, 0.6)
    else:
      # 15% have chronic late filing issues
      if random.random() < 0.15:
        late_filing_rate = random.uniform(0.5, 0.8)
      else:
        late_filing_rate = random.uniform(0, 0.3)

      # 15% have chronic late payment issues
      if random.random() < 0.15:
        late_payment_rate = random.uniform(0.4, 0.7)
      else:
        late_payment_rate = random.uniform(0, 0.3)

      # 10% have frequent amendments
      if random.random() < 0.10:
        amendment_rate = random.uniform(0.3, 0.6)
      else:
        amendment_rate = random.uniform(0, 0.2)
    income_volatility = random.uniform(0.1, 0.8)
    avg_deduction_ratio = random.uniform(0.1, 0.4)

    record = {
      'taxpayer_id': taxpayer_id,
      'declaration_id': self.generate_declaration_id(taxpayer_id, year, has_crypto),
      'tax_year': year,
      'taxpayer_type': 'INDIVIDUAL',
      'industry_code': None,
      'address_state': random.choice(self.regions),
      'first_name': random.choice(self.first_names),
      'last_name': random.choice(self.last_names),
      'company_name': None,
      'date_of_birth': date(random.randint(1950, 2000),
                            random.randint(1, 12),
                            random.randint(1, 28)),
      'gross_income': round(gross_income, 2),
      'taxable_income': round(taxable_income, 2),
      'total_deductions': round(total_deductions, 2),
      'calculated_tax': round(calculated_tax, 2),
      'has_crypto_account': has_crypto,
      'crypto_exchange_name': crypto_exchange,
      'crypto_account_verified_date': crypto_verified_date,
      'declared_crypto_income': round(crypto_income, 2),
      'crypto_transaction_count': crypto_transactions,
      'has_declared_crypto_previously': has_declared_crypto_prev,
      'filing_date': filing_date,
      'is_late_filing': is_late_filing,
      'has_amendments': random.random() < 0.1,
      'days_filing_delay': days_filing_delay,
      'is_late_payment': is_late_payment,
      'days_payment_delay': days_payment_delay,
      'payment_date': payment_date,
      'late_filing_rate': round(late_filing_rate, 3),
      'late_payment_rate': round(late_payment_rate, 3),
      'amendment_rate': round(amendment_rate, 3),
      'income_volatility': round(income_volatility, 3),
      'avg_deduction_ratio': round(avg_deduction_ratio, 3),
      'data_source': data_source,
      'created_at': datetime.now(),
      'updated_at': datetime.now()
    }

    # Calculate derived fields
    record = self.calculate_derived_fields(record)
    record = self.determine_anomaly(record)

    return record

  def generate_business_record(self, year: int, data_source: str, force_non_crypto_anomaly: bool = False) -> Dict:
    """Generate a single business taxpayer record"""
    taxpayer_id = self.generate_taxpayer_id('BUS')

    # Business income (wider range)
    income_bracket = random.choices(
      ['small', 'medium', 'large', 'enterprise'],
      weights=[50, 30, 15, 5]
    )[0]

    if income_bracket == 'small':
      gross_income = random.uniform(50000, 250000)
    elif income_bracket == 'medium':
      gross_income = random.uniform(250000, 1000000)
    elif income_bracket == 'large':
      gross_income = random.uniform(1000000, 5000000)
    else:  # enterprise
      gross_income = random.uniform(5000000, 50000000)

    # Business deductions (typically higher, 20-60%)
    # Force high deductions if creating intentional non-crypto anomaly
    if force_non_crypto_anomaly:
      deduction_pct = random.uniform(0.7, 0.9)
    elif random.random() < 0.10:  # 10% have suspiciously high deductions
      deduction_pct = random.uniform(0.7, 0.9)
    elif random.random() < 0.18:  # 18% have elevated deductions
      deduction_pct = random.uniform(0.6, 0.7)
    else:
      deduction_pct = random.uniform(0.2, 0.6)

    total_deductions = gross_income * deduction_pct
    taxable_income = max(0, gross_income - total_deductions)

    # Corporate tax (simplified rate ~30%)
    calculated_tax = taxable_income * 0.30

    # Crypto data - realistic percentages based on data source
    if data_source == 'TRAINING':
      # Training data: 25% have crypto (historical data)
      crypto_probability = 0.25
    else:
      # NEW_FILING: 8% have crypto (more realistic for general business population)
      crypto_probability = 0.08

    has_crypto = random.random() < crypto_probability
    crypto_income = 0
    crypto_transactions = 0
    crypto_exchange = None
    crypto_verified_date = None
    has_declared_crypto_prev = False

    if has_crypto:
      crypto_exchange = random.choice(self.crypto_exchanges)
      crypto_verified_date = date(year - random.randint(0, 2),
                                  random.randint(1, 12),
                                  random.randint(1, 28))
      crypto_transactions = random.randint(10, 1000)
      has_declared_crypto_prev = random.random() < 0.7

      # 25% of business crypto holders don't declare income
      if random.random() < 0.75:
        crypto_income = random.uniform(1000, gross_income * 0.1)

    # Filing behavior (businesses often file later)
    filing_date = date(year + 1, random.randint(6, 12), random.randint(1, 28))
    is_late_filing = filing_date > date(year + 1, 7, 31)
    days_filing_delay = max(0, (filing_date - date(year + 1, 7, 31)).days)

    # Payment behavior - more variation to create anomalies
    if random.random() < 0.15:  # 15% have severe payment delays
      payment_date = filing_date + timedelta(days=random.randint(120, 180))
    else:
      payment_date = filing_date + timedelta(days=random.randint(0, 90))
    is_late_payment = payment_date > filing_date + timedelta(days=45)
    days_payment_delay = max(0, (payment_date - filing_date - timedelta(days=45)).days)

    # Historical patterns (businesses with more anomalies)
    # Force problematic patterns if creating intentional non-crypto anomaly
    if force_non_crypto_anomaly:
      late_filing_rate = random.uniform(0.5, 0.7)
      late_payment_rate = random.uniform(0.4, 0.6)
      amendment_rate = random.uniform(0.3, 0.5)
    else:
      # 12% have chronic late filing issues
      if random.random() < 0.12:
        late_filing_rate = random.uniform(0.5, 0.7)
      else:
        late_filing_rate = random.uniform(0, 0.3)

      # 12% have chronic late payment issues
      if random.random() < 0.12:
        late_payment_rate = random.uniform(0.4, 0.6)
      else:
        late_payment_rate = random.uniform(0, 0.3)

      # 15% have frequent amendments
      if random.random() < 0.15:
        amendment_rate = random.uniform(0.3, 0.5)
      else:
        amendment_rate = random.uniform(0, 0.3)

    income_volatility = random.uniform(0.2, 0.9)
    avg_deduction_ratio = random.uniform(0.2, 0.6)

    record = {
      'taxpayer_id': taxpayer_id,
      'declaration_id': self.generate_declaration_id(taxpayer_id, year, has_crypto),
      'tax_year': year,
      'taxpayer_type': 'BUSINESS',
      'industry_code': random.choice(self.industry_codes),
      'address_state': random.choice(self.regions),
      'first_name': None,
      'last_name': None,
      'company_name': random.choice(self.company_names),
      'date_of_birth': None,
      'gross_income': round(gross_income, 2),
      'taxable_income': round(taxable_income, 2),
      'total_deductions': round(total_deductions, 2),
      'calculated_tax': round(calculated_tax, 2),
      'has_crypto_account': has_crypto,
      'crypto_exchange_name': crypto_exchange,
      'crypto_account_verified_date': crypto_verified_date,
      'declared_crypto_income': round(crypto_income, 2),
      'crypto_transaction_count': crypto_transactions,
      'has_declared_crypto_previously': has_declared_crypto_prev,
      'filing_date': filing_date,
      'is_late_filing': is_late_filing,
      'has_amendments': random.random() < 0.15,
      'days_filing_delay': days_filing_delay,
      'is_late_payment': is_late_payment,
      'days_payment_delay': days_payment_delay,
      'payment_date': payment_date,
      'late_filing_rate': round(late_filing_rate, 3),
      'late_payment_rate': round(late_payment_rate, 3),
      'amendment_rate': round(amendment_rate, 3),
      'income_volatility': round(income_volatility, 3),
      'avg_deduction_ratio': round(avg_deduction_ratio, 3),
      'data_source': data_source,
      'created_at': datetime.now(),
      'updated_at': datetime.now()
    }

    # Calculate derived fields
    record = self.calculate_derived_fields(record)
    record = self.determine_anomaly(record)

    return record

  def generate_dataset(self, training_rows: int, new_filing_rows: int,
      year: int = 2023) -> pd.DataFrame:
    """Generate complete dataset"""
    all_records = []

    print(f"Generating {training_rows} training records...")
    for i in range(training_rows):
      if i % 100 == 0:
        print(f"  Generated {i}/{training_rows} training records")

      # 70% individuals, 30% businesses
      if random.random() < 0.7:
        record = self.generate_individual_record(year, 'TRAINING')
      else:
        record = self.generate_business_record(year, 'TRAINING')
      all_records.append(record)

    print(f"Generating {new_filing_rows} new filing records...")
    # Track non-crypto anomalies to ensure we have some
    non_crypto_anomaly_count = 0
    target_non_crypto_anomalies = max(5, int(new_filing_rows * 0.3))  # At least 30% should be non-crypto anomalies

    for i in range(new_filing_rows):
      if i % 100 == 0:
        print(f"  Generated {i}/{new_filing_rows} new filing records")

      # Force some non-crypto anomalies in NEW_FILING
      force_non_crypto = (non_crypto_anomaly_count < target_non_crypto_anomalies and
                          random.random() < 0.4)  # 40% chance when below target

      # 70% individuals, 30% businesses
      if random.random() < 0.7:
        record = self.generate_individual_record(year, 'NEW_FILING', force_non_crypto_anomaly=force_non_crypto)
      else:
        record = self.generate_business_record(year, 'NEW_FILING', force_non_crypto_anomaly=force_non_crypto)

      # Track if this is a non-crypto anomaly
      if record.get('is_anomaly') and not record.get('has_crypto_account'):
        non_crypto_anomaly_count += 1

      all_records.append(record)

    print(f"  NEW_FILING: {non_crypto_anomaly_count} non-crypto anomalies created")

    # Define column order to match BigQuery schema exactly
    column_order = [
      # Identifiers
      'taxpayer_id', 'declaration_id', 'tax_year',

      # Taxpayer basic info
      'taxpayer_type', 'industry_code', 'address_state',
      'first_name', 'last_name', 'company_name', 'date_of_birth',

      # Financial data
      'gross_income', 'taxable_income', 'total_deductions', 'calculated_tax',

      # Cryptocurrency data
      'has_crypto_account', 'crypto_exchange_name', 'crypto_account_verified_date',
      'declared_crypto_income', 'crypto_transaction_count', 'has_declared_crypto_previously',

      # Calculated ratios and derived features
      'deduction_ratio', 'tax_ratio', 'crypto_income_ratio',

      # Key crypto anomaly flags
      'is_crypto_non_declarant', 'crypto_risk_score',

      # Filing behavior
      'filing_date', 'is_late_filing', 'has_amendments', 'days_filing_delay',

      # Payment behavior
      'is_late_payment', 'days_payment_delay', 'payment_date',

      # Historical patterns
      'late_filing_rate', 'late_payment_rate', 'amendment_rate',
      'income_volatility', 'avg_deduction_ratio',

      # Target variables
      'is_anomaly', 'anomaly_type', 'anomaly_confidence',

      # Metadata
      'data_source', 'created_at', 'updated_at'
    ]

    df = pd.DataFrame(all_records)

    # Ensure columns are in the correct order
    df = df[column_order]

    # Round numeric columns
    numeric_cols = df.select_dtypes(include=[np.number]).columns
    df[numeric_cols] = df[numeric_cols].round(3)

    return df

def main():
  parser = argparse.ArgumentParser(description='Generate tax office training data')
  parser.add_argument('--training-rows', type=int, default=1000000,
                      help='Number of training records to generate')
  parser.add_argument('--new-filing-rows', type=int, default=100,
                      help='Number of new filing records to generate')
  parser.add_argument('--year', type=int, default=2023,
                      help='Tax year for the data')
  parser.add_argument('--output', type=str, default='tax_office_data.csv',
                      help='Output CSV filename')
  parser.add_argument('--seed', type=int, default=42,
                      help='Random seed for reproducibility')

  args = parser.parse_args()

  print("Tax Office Data Generator")
  print("========================")
  print(f"Training rows: {args.training_rows}")
  print(f"New filing rows: {args.new_filing_rows}")
  print(f"Tax year: {args.year}")
  print(f"Output file: {args.output}")
  print(f"Random seed: {args.seed}")
  print()

  generator = TaxDataGenerator(seed=args.seed)
  df = generator.generate_dataset(args.training_rows, args.new_filing_rows, args.year)

  print("\nDataset generated successfully!")
  print(f"Total records: {len(df)}")
  print(f"Training records: {len(df[df['data_source'] == 'TRAINING'])}")
  print(f"New filing records: {len(df[df['data_source'] == 'NEW_FILING'])}")
  print(f"Anomalies: {len(df[df['is_anomaly'] == True])}")
  print(f"Anomaly rate: {len(df[df['is_anomaly'] == True]) / len(df) * 100:.1f}%")

  # Save to CSV
  print("\nExporting CSV data. Might take a while...")
  df.to_csv(args.output, index=False)
  print(f"\nData exported to: {args.output}")

  # Show sample statistics
  print("\nSample statistics:")
  print(f"Individual taxpayers: {len(df[df['taxpayer_type'] == 'INDIVIDUAL'])}")
  print(f"Business taxpayers: {len(df[df['taxpayer_type'] == 'BUSINESS'])}")
  print("\nCrypto statistics (overall):")
  print(f"  Crypto account holders: {len(df[df['has_crypto_account'] == True])} ({len(df[df['has_crypto_account'] == True]) / len(df) * 100:.1f}%)")
  print(f"  Crypto non-declarants: {len(df[df['is_crypto_non_declarant'] == True])}")

  # Training data crypto stats
  training_df = df[df['data_source'] == 'TRAINING']
  print("\nCrypto in TRAINING data:")
  print(f"  Total: {len(training_df)}")
  print(f"  With crypto: {len(training_df[training_df['has_crypto_account'] == True])} ({len(training_df[training_df['has_crypto_account'] == True]) / len(training_df) * 100:.1f}%)")

  # NEW_FILING data crypto stats
  new_filing_df = df[df['data_source'] == 'NEW_FILING']
  print("\nCrypto in NEW_FILING data:")
  print(f"  Total: {len(new_filing_df)}")
  print(f"  With crypto: {len(new_filing_df[new_filing_df['has_crypto_account'] == True])} ({len(new_filing_df[new_filing_df['has_crypto_account'] == True]) / len(new_filing_df) * 100:.1f}%)")

  # NEW_FILING anomaly breakdown
  new_filing_anomalies = new_filing_df[new_filing_df['is_anomaly'] == True]
  crypto_anomalies = new_filing_anomalies[new_filing_anomalies['has_crypto_account'] == True]
  non_crypto_anomalies = new_filing_anomalies[new_filing_anomalies['has_crypto_account'] == False]

  print("\nNEW_FILING Anomalies Breakdown:")
  print(f"  Total anomalies: {len(new_filing_anomalies)} ({len(new_filing_anomalies) / len(new_filing_df) * 100:.1f}%)")
  print(f"  Crypto-related: {len(crypto_anomalies)} ({len(crypto_anomalies) / len(new_filing_anomalies) * 100:.1f}% of anomalies)")
  print(f"  Non-crypto: {len(non_crypto_anomalies)} ({len(non_crypto_anomalies) / len(new_filing_anomalies) * 100:.1f}% of anomalies)")

  # Show crypto filings details
  crypto_new_filings = new_filing_df[new_filing_df['has_crypto_account'] == True]
  if len(crypto_new_filings) > 0:
    print("\nCrypto NEW_FILING Declaration IDs:")
    for idx, row in crypto_new_filings.iterrows():
      anomaly_indicator = " [ANOMALY]" if row['is_anomaly'] else ""
      print(f"  - {row['declaration_id']} (TaxpayerID: {row['taxpayer_id']}, Type: {row['taxpayer_type']}, Exchange: {row['crypto_exchange_name']}){anomaly_indicator}")

  # Show non-crypto anomaly examples
  if len(non_crypto_anomalies) > 0:
    print("\nNon-Crypto NEW_FILING Anomalies (sample):")
    for idx, row in non_crypto_anomalies.head(10).iterrows():
      print(f"  - {row['declaration_id']} (TaxpayerID: {row['taxpayer_id']}, Type: {row['taxpayer_type']}, Reasons: {row['anomaly_type']})")

if __name__ == '__main__':
  main()
