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
import datetime
import unittest
from . import generate_tax_data as generate

Date = datetime.date


class TaxDataGeneratorTest(unittest.TestCase):
  def setUp(self):
    super().setUp()
    self.generator = generate.TaxDataGenerator(seed=42)

  def test_generate_taxpayer_id(self):
    # Test individual taxpayer ID generation
    tp_id = self.generator.generate_taxpayer_id('IND')
    self.assertTrue(tp_id.startswith('IND_'))
    self.assertEqual(len(tp_id.split('_')), 2)

    bus_id = self.generator.generate_taxpayer_id('BUS')
    self.assertTrue(bus_id.startswith('BUS_'))

  def test_generate_declaration_id(self):
    # Test declaration ID generation for both non-crypto and crypto
    taxpayer_id = 'IND_123456'
    year = 2023

    # Non-crypto
    decl_id = self.generator.generate_declaration_id(taxpayer_id, year, False)
    self.assertTrue(decl_id.startswith('DECL_IND_123456_2023_'))

    # Crypto
    decl_id_crypto = self.generator.generate_declaration_id(taxpayer_id, year, True)
    self.assertTrue(decl_id_crypto.startswith('DECL_CRYP_IND_123456_2023_'))

  def test_calculate_derived_fields(self):
    # Test with typical individual income and deductions
    row = {
      'gross_income': 100000.0,
      'total_deductions': 20000.0,
      'declared_crypto_income': 5000.0,
      'taxable_income': 80000.0,
      'calculated_tax': 24000.0,
      'has_crypto_account': True,
      'crypto_transaction_count': 150,
      'has_declared_crypto_previously': False,
    }
    updated_row = self.generator.calculate_derived_fields(row.copy())

    self.assertEqual(updated_row['deduction_ratio'], 0.2)
    self.assertEqual(updated_row['crypto_income_ratio'], 0.05)
    self.assertEqual(updated_row['tax_ratio'], 0.3)
    self.assertFalse(updated_row['is_crypto_non_declarant'])
    # Risk score calculation:
    # not declared previously + has account: +0.2
    # transaction count > 100: +0.3
    # Total: 0.5
    self.assertAlmostEqual(updated_row['crypto_risk_score'], 0.5)

  def test_calculate_derived_fields_zero_income(self):
    # Test with zero income and no crypto activity
    row = {
      'gross_income': 0.0,
      'total_deductions': 0.0,
      'declared_crypto_income': 0.0,
      'taxable_income': 0.0,
      'calculated_tax': 0.0,
      'has_crypto_account': False,
      'crypto_transaction_count': 0,
      'has_declared_crypto_previously': False,
    }
    updated_row = self.generator.calculate_derived_fields(row.copy())
    self.assertEqual(updated_row['deduction_ratio'], 0)
    self.assertEqual(updated_row['crypto_income_ratio'], 0)
    self.assertEqual(updated_row['tax_ratio'], 0)

  def test_determine_anomaly_high_deductions(self):
    # High deduction ratio, no crypto activity
    row = {
      'deduction_ratio': 0.7,
      'is_crypto_non_declarant': False,
      'crypto_transaction_count': 0,
      'late_filing_rate': 0.1,
      'days_payment_delay': 0,
      'late_payment_rate': 0.1,
      'income_volatility': 0.1,
      'amendment_rate': 0.1,
    }
    updated_row = self.generator.determine_anomaly(row.copy())
    self.assertTrue(updated_row['is_anomaly'])
    self.assertIn('HIGH_DEDUCTIONS', updated_row['anomaly_type'])

  def test_determine_anomaly_crypto_evasion(self):
    # High crypto transaction count, not declared previously, has account
    row = {
      'deduction_ratio': 0.2,
      'is_crypto_non_declarant': True,
      'crypto_transaction_count': 100,
      'late_filing_rate': 0.1,
      'days_payment_delay': 0,
      'late_payment_rate': 0.1,
      'income_volatility': 0.1,
      'amendment_rate': 0.1,
    }
    updated_row = self.generator.determine_anomaly(row.copy())
    self.assertFalse(updated_row['is_anomaly'])  # score 0.35, threshold 0.4
    self.assertIn('CRYPTO_EVASION', updated_row['anomaly_type'])

  def test_generate_individual_record(self):
    # Generate an individual record with training data source
    record = self.generator.generate_individual_record(2023, 'TRAINING')
    self.assertEqual(record['taxpayer_type'], 'INDIVIDUAL')
    self.assertIn('taxpayer_id', record)
    self.assertIn('gross_income', record)
    self.assertIsInstance(record['filing_date'], Date)

  def test_generate_business_record(self):
    # Generate a business record with forced non-crypto anomaly
    record = self.generator.generate_business_record(2023, 'NEW_FILING')
    self.assertEqual(record['taxpayer_type'], 'BUSINESS')
    self.assertIn('company_name', record)
    self.assertIsNone(record['first_name'])

  def test_generate_dataset(self):
    # Generate dataset with 10 training records and 5 new filing records
    df = self.generator.generate_dataset(10, 5, 2023)
    self.assertEqual(len(df), 15)
    self.assertEqual(len(df[df['data_source'] == 'TRAINING']), 10)
    self.assertEqual(len(df[df['data_source'] == 'NEW_FILING']), 5)
    # Check if key columns exist
    self.assertIn('taxpayer_id', df.columns)
    self.assertIn('is_anomaly', df.columns)
