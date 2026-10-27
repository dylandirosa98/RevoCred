import '../models/app_models.dart';

const strategyRolesExplanation =
    'This is a map of wallet roles, not a shopping list. Cards you own already fill roles; unavailable cards are not applications to make now.';
const strategyEligibilityExplanation =
    'Future roles may become eligible as your credit profile, issuer rules and spending change. Reassess before applying; timing and approval are not guaranteed.';

String strategyValueExplanation(AppData data) => data.ongoingValue == null
    ? 'Current wallet estimate only, not the completed strategy. Target fees shown separately. No benefit breakdown is available; do not assume credits or bonuses are included. Not guaranteed.'
    : 'Current wallet only: spending rewards + conditional usable credits (70% for reviewed relevant credits) + recurring anniversary rewards - annual fees. One cent per point/mile. Enrollment, merchant use, caps and renewal eligibility apply; credited purchases may not earn points. Excludes welcome bonuses and travel redemption uplift. Target fees shown separately; not guaranteed.';
