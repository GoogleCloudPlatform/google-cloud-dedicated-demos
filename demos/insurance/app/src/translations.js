/*
 * Copyright 2026 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
function currentLanguage() {
  if (navigator.languages.includes("fr")) return "fr";
  if (navigator.languages.includes("en")) return "en";

  return "fr";
}

export function currentLangText(textMap, replacementMap) {
  const currentLang = currentLanguage();

  const entries =
    textMap instanceof Map ? [...textMap.entries()] : Object.entries(textMap);

  console.assert(entries.length >= 1);

  const textEntry = entries.find((entry) => entry[0] == currentLang);
  let text = textEntry[1] ?? entries[0][1];

  if (!replacementMap) return text;

  for (const replacementKey in replacementMap) {
    text = text.replaceAll(replacementKey, replacementMap[replacementKey]);
  }

  return text;
}

export const TEXT_MAPS = {
  DUMMY_SUCCESS_ANALYSIS_ITEMS_LANG_MAP: {
    en: "Patient eligibility confirmed and benefits are active",
    fr: "L'éligibilité du patient est confirmée et les avantages sont actifs",
  },
  DUMMY_ERROR_ANALYSIS_ITEMS_LANG_MAP: {
    en: "Provider has high history of similar claims and duplicate service within 30-day period",
    fr: "Le fournisseur a un historique élevé de demandes de remboursement similaires et de services en double dans une période de 30 jours",
  },
  RISK_SCORE_BELOW_CUT_OFF: {
    en: "Recommended for approval, based on a predicted score SCORE/100 from ML model",
    fr: "Recommandé pour approbation, sur la base d'un score prédit SCORE/100 à partir du modèle ML",
  },
  RISK_SCORE_ABOVE_CUT_OFF: {
    en: "Further investigation required, based on a predicted score SCORE/100 from the ML model",
    fr: "Des recherches plus approfondies sont nécessaires, sur la base d'un score prédit SCORE/100 à partir du modèle ML",
  },
  UNDER_REVIEW: {
    en: "Under Review",
    fr: "En cours de révision",
  },
  BALANCED_FORMULA: {
    en: "Balanced Formula",
    fr: "Formule équilibrée",
  },
  DATE_OF_SERVICE: {
    en: "Date of Service",
    fr: "Date de prestation",
  },
  SERIVCE_TYPE: {
    en: "Service Type",
    fr: "Type de services",
  },
  PROVIDER: {
    en: "Provider",
    fr: "Fournisseur",
  },
  AMOUNT_BILLED: {
    en: "Amount Billed",
    fr: "Montant facturé",
  },
  PUBLIC_INSURANCE_BASE: {
    en: "Public Insurance Base",
    fr: "Base d'assurance publique",
  },
  MUTUAL_COVERAGE: {
    en: "Mutual Coverage",
    fr: "Couverture par la mutuelle",
  },
  ANALYZE_CLAIM: {
    en: "Analyze Claim",
    fr: "Analyser la demande de remboursement",
  },
  CLAIM: {
    en: "Claim",
    fr: "Demande de remboursement",
  },
  AI_POWERED_RISK_AANALYSIS: {
    en: "AI Powered Risk Analysis",
    fr: "Analyse des risques alimentée par l'IA",
  },
  THRESHOLD: {
    en: "Threshold",
    fr: "Seuil",
  },
  REQUEST_MORE_INFO: {
    en: "Request More Info",
    fr: "Demander plus d'informations",
  },
  APPROVE: {
    en: "Approve",
    fr: "Approuver",
  },
  REQUEST_DOCUMENTATION: {
    en: "Request Documentation",
    fr: "Demander des documents",
  },
  ESCALATE_TO_INVESTIGATOR: {
    en: "Escalate to Investigator",
    fr: "Transférer à l'enquêteur",
  },
  OVERRIDE_AND_APPROVE: {
    en: "Override & Approve",
    fr: "Remplacer et approuver",
  },
  HOW_DOES_RISK_WORK_RESPONSE: {
    en: "Risk analysis uses AI to evaluate several factors such as patient history, claim frequency, and consistency of provided documents. Each claim receives a risk score that determines whether it can be processed automatically or requires manual review.",
    fr: "L'analyse des risques utilise l'IA pour évaluer plusieurs facteurs tels que les antécédents du patient, la fréquence des demandes de remboursement et la cohérence des documents fournis. Chaque demande de remboursement reçoit un score de risque qui détermine si elle peut être traitée automatiquement ou nécessite une vérification manuelle.",
  },
  RISK_FACTORS_RESPONSE: {
    en: "The main risk factors include: duplicate claims, inconsistencies in documentation, unusual frequency of claims, abnormally high amounts, and provider history.",
    fr: "Les principaux facteurs de risque comprennent : les demandes en double, les incohérences dans la documentation, la fréquence inhabituelle des demandes, les montants anormalement élevés et l'historique du fournisseur.",
  },
  FLAGGED_CASE_RESPONSE: {
    en: "For flagged cases, we recommend: 1) Verify missing documentation, 2) Compare with patient history, 3) Contact the provider if necessary, and 4) Document your decision to improve AI models.",
    fr: "Pour les cas signalés, nous recommandons : 1) de vérifier la documentation manquante, 2) de comparer avec l'historique du patient, 3) de contacter le fournisseur si nécessaire et 4) de documenter votre décision d'améliorer les modèles d'IA.",
  },
  LOGIN_TITLE: {
    en: "Insurance App Login",
    fr: "Connexion Application Assurance",
  },
  LOGIN_USERNAME: {
    en: "Username",
    fr: "Nom d'utilisateur",
  },
  LOGIN_PASSWORD: {
    en: "Password",
    fr: "Mot de passe",
  },
  LOGIN_SUBMIT: {
    en: "Sign In",
    fr: "Se connecter",
  },
  LOGOUT: {
    en: "Sign Out",
    fr: "Déconnexion",
  },
  LOGIN_ERROR: {
    en: "Invalid username or password",
    fr: "Nom d'utilisateur ou mot de passe incorrect",
  },
};
