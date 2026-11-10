# Publishing legal documents

These are drafts requiring owner completion and legal review before release. Replace every {{LEGAL_ENTITY}}, {{SUPPORT_EMAIL}}, {{JURISDICTION}} and {{EFFECTIVE_DATE}} placeholder. Confirm provider agreements, operational backup retention and applicable legal rights with counsel; add the actual backup schedule before publishing.

Host both completed documents at public HTTPS URLs accessible without sign-in. Set REVOCRED_LEGAL_ENTITY, REVOCRED_SUPPORT_EMAIL, REVOCRED_LEGAL_JURISDICTION, REVOCRED_LEGAL_EFFECTIVE_DATE, REVOCRED_PRIVACY_URL and REVOCRED_TERMS_URL in the public build defines. Enter the privacy policy URL in App Store Connect and include the terms URL in the relevant listing/review information. Verify both links and support email in the signed build. Release validation is offline and does not prove the pages are hosted.

## Static public-page package

No final policies are approved in this checkout. The November 8 audit found
`https://revocred.com/privacy`, `/terms` and `/support` returning 404. The marketing
site's source/hosting configuration is not in this repository; the Flutter
Nginx deployment is a different application and changing it alone will not fix
those public URLs. Do not replace the marketing root with this package.

Complete the factual placeholders in all three Markdown documents, then copy
`public-pages.example.json` to a page manifest beside those documents. Generate
a fresh local directory for review:

```sh
python3 scripts/build_public_pages.py --manifest docs/legal/public-pages.json --output .local/public-pages
```

The command is offline, rejects unresolved placeholders/draft markers and writes
`privacy/index.html`, `terms/index.html`, `support/index.html` and a navigation
index. It renders plain paragraphs, headings and bullets; inline Markdown is
shown literally. All source content is HTML-escaped. Review the generated text
and layout before deployment. It never publishes or modifies hosting.

For the existing marketing host, copy the three page directories into its
public static assets and configure `/privacy`, `/terms` and `/support` to serve
them; preserve the existing home page. `deploy/public-pages.nginx.conf` is an
optional standalone Nginx configuration, including canonical-path redirects and
a `/privacy-policy` alias. It requires existing TLS termination. Sites hosting
can also serve the static package once the intended Site identity/audience and
public domain are confirmed; this task has not created a Site or changed DNS.

Before calling the finding closed, verify all three exact HTTPS URLs without
sign-in, every navigation link, the privacy alias if used, and delivery/replies
from the approved contact. Configure the verified policy URLs in the release
and App Store Connect. A locally generated package does not establish public
availability or a monitored support channel.

Still required from the owner/hosting operator:

- Legal operator/controller identity, applicable jurisdiction, effective date,
  rights/request handling and audience/territory policy.
- One verified monitored support/privacy contact; reconcile the `.com` and
  `.app` contacts found on the live marketing site.
- Actual hosting/Auth/email/support logging and retention, backup expiry and
  deletion/recovery practices, final AI/search recipients and their agreements,
  retention/data-use/transfer facts, plus applicable commercial disclosures.
- Source repository or authorized deployment access for the existing marketing
  host and confirmation of the exact public URLs. No new cost, account, domain,
  DNS mutation or publication is part of this offline package.

Read-only connected-host inventory on November 8: the Sites account listed one
unrelated site and no RevoCred site; a Vercel project-name search for `revocred`
returned no projects in the connected account. This does not establish absence
from another account or provider, and supplies no deployment mapping for
`revocred.com`.
