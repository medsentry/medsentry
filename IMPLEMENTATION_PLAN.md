# MedSentry Advanced EMR Implementation Plan

## Phase 1: Core Infrastructure & Models
- [ ] Update Patient model with comprehensive demographic fields
- [ ] Create VitalSigns model for triage
- [ ] Create Medication/Prescription models for pharmacy
- [ ] Create ImmunizationRecord model for EPI
- [ ] Create PrenatalRecord model for MCH
- [ ] Create MedicalSnippet model for dot phrases
- [ ] Update database tables for new models

## Phase 2: Smart Triage & Priority Queueing
- [ ] Implement triage scoring algorithm
- [ ] Add priority flags to QueueItem
- [ ] Update queue screen with color-coded priority cards
- [ ] Add vital signs capture to triage panel
- [ ] Implement red flag alerts (BP > 160/100, etc.)

## Phase 3: Advanced Forms with Conditional Logic
- [ ] Master Patient Registration (Tabbed Face Sheet)
  - Tab 1: Basic Demographics & Identifiers
  - Tab 2: Socio-Economic & Vulnerability (4Ps, IP, etc.)
  - Tab 3: Environmental & Sanitation (Water, Toilet)
- [ ] Nurse Intake & Vitals (Triage Panel)
  - Vital signs with auto BMI calculation
  - Pain scale slider
  - Red flag checkboxes
- [ ] Doctor's SOAP Note with ICD-10 integration
  - Subjective with ROS checkboxes
  - Objective with "Essentially Normal" toggle
  - Assessment with ICD-10 search
  - Plan with medication dispensing
- [ ] Specialized Program Forms
  - EPI Immunization Card
  - Prenatal Care Form with EDD/AOG calculation

## Phase 4: Pharmacy & Inventory
- [ ] Medicine inventory management
- [ ] Prescription integration with SOAP notes
- [ ] Stock level alerts
- [ ] Dispensing tracking

## Phase 5: FHSIS Reporting
- [ ] Report templates for DOH requirements
- [ ] Auto-generation of demographic tables
- [ ] Export to PDF/Excel

## Phase 6: Smart Text Snippets (Dot Phrases)
- [ ] Snippet expansion system
- [ ] Pre-configured medical templates (.htn, .dm, etc.)
- [ ] User-defined snippets

## Phase 7: Audit Trail & Compliance
- [ ] Field-level change logging
- [ ] Rollback functionality
- [ ] Data Privacy Act compliance features
