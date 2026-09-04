# SIH six-slide content

## 1. Idea title
**AI-Based Cognitive Gaming and Memory Assistance Platform for Elderly Dementia Patients in NER**  
PS ID 26003 · MedTech / BioTech / HealthTech · Software · Team Candy Crush

## 2. Idea
Remote and rural settings can combine caregiving strain, low connectivity, and limited culturally familiar digital engagement. Cognitive Care offers large-touch-target activities, routines/reminders, regional-language architecture, local content packs, and consented caregiver insights.

`Patient → play → performance → rule-based personalization → next activity → caregiver insight`

## 3. Technical approach
Flutter app (local queue) → JWT → FastAPI game and reminder APIs → MongoDB. Server-side scoring protects game attempts; consented caregiver links prevent unauthorized access. Voice uses a configurable text-first intent interface, and ML remains an optional validated difficulty recommender.

## 4. Feasibility and viability
Flutter, FastAPI, MongoDB, and local persistence are open-source and deployable on ordinary Android phones/tablets. Offline event queuing supports unreliable networks. The initial recommender is explainable rule-based logic, so it works without a large clinical dataset.

## 5. Impact and benefits
Elderly users receive accessible routine support and gentle game engagement. Caregivers get consented activity visibility rather than medical conclusions. Communities gain an extensible, low-connectivity-ready platform with NER-relevant language and content architecture.

## 6. Research and references
Use the credible sources listed in [references.md](references.md). State clearly that this prototype is non-diagnostic and makes no guaranteed clinical-outcome claim.
