# Beta review submission failure

Status: sent through Apple Developer Support's Distribution > TestFlight email form
on November 7, 2026 (Toronto), after Rami's explicit approval. Apple confirmed
case ID **30000008606157** and said it would review the message and reply by email.
The form used the signed-in Apple Account email. No demo credentials were sent.

The report below was submitted as the message, with app/build/platform, last
occurrence and reproduction steps also entered in the form's dedicated fields.

Subject: Mux Chat build 0.1.0 (3) cannot be submitted to Beta App Review

App ID: 6831890438
Team ID: 3V2UU7RRK9
Build resource: 0f53ef69-5696-4c46-8cd5-69afc684cebc

Please investigate why this processed build cannot be submitted to Beta App Review.
The App Store Connect website reports: "There was an error processing your request.
Please try again later." Earlier network inspection showed
`POST /iris/v1/betaAppReviewSubmissions` returning HTTP 422 with code
`ENTITY_UNPROCESSABLE` and no field-specific error. The error has persisted across
four attempts, including a new browser tab using a logged-in session.

The build shows Ready to Submit. Export compliance is saved with no France
distribution. Beta description, feedback email, review contact, staged demo sign-in
and review notes are saved; What to Test is also saved. The optional marketing URL
is populated; privacy-policy URL and custom license text are empty. No demo
credentials are included in this report.

Both Free and Paid Apps agreements and DSA compliance show Active in Business.
Apple Developer shows the program license issued October 29, 2026 accepted
November 7, 2026, with no pending acceptance banner.

To reproduce: open TestFlight, select external group Teammates External, add
build 3, continue past What to Test and click Submit for Review. The error appears
and the group retains zero builds. The same failure occurred through build details.

Please identify the blocking validation or account/app state and advise how to
complete submission. No successful external-review submission has been observed.
