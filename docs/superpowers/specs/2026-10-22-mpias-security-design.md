# MPIAS security: watch, triage, respond, harden

Design for [ISS#48](https://github.com/mpimedia/mpi-application-workflows/issues/48). Written 2026-10-22, from the HC's brainstorming session with Claude. Lines marked **(HC)** are the HC's decisions. Lines marked **(Claude's call)** are defaults the HC heard and didn't overrule, and may be changed. Everything else is left to the builder.

## Why

The HC, 2026-10-21: "I want us to be on top of published alerts, news about issues, gem and package releases, linux-related updates, etc. I need to be able to know quickly if we need to apply patches for parts of our infrastructure, no matter what buffer dates we have for usual upgrades."

Today, security news reaches the HC only when it happens to cross the Rails or Node mailing lists. No one is assigned to watch for it. Two things prompted this work:

- The eMudhra incident (Ars Technica, 2026-10-20). Eight intermediate CA certificates with keys of 3–8 bits had to be distrusted everywhere. For us the question is our trust stores, not our website certificates: `ca-certificates` in the `ruby:*-slim` images and on the droplets, and Node's bundled root store.
- A PHP bug in the news the same day. We don't run PHP, so the HC never needs to hear about it.

The threat model follows Nate Berkopec's framing (X, 2026-10-22): cheap models (DeepSeek V4.1, GLM 5.3) put exploitation within reach of anyone. What matters is **what is being exploited** and **how exposed we are**, more than the raw number of CVEs. Services that anyone can reach without an account suffer most. The response bar to aim for is to "react to a CVE being published with a correct upgrade and deploy within 60 minutes".

## What success looks like

- When something affects us, an issue appears in the repo where the fix will happen. It says three things:
  - **the risk profile:** whether it's being exploited and how exposed we are;
  - **how we're affected:** the exact repos, files, versions and hosts;
  - **what to do:** the fix, any interim mitigation, and the options to discuss. **(HC)**
- Theo's weekday sweep brings each urgent issue to the HC, and Postmark sends an email nudge. **(HC)**
- For an urgent, exploited, internet-reachable vulnerability that a simple version bump fixes:
  - the upgrade PR, CI and a staging deploy happen without anyone acting;
  - the HC approves production with one tap;
  - the whole loop can finish inside 60 minutes when the HC is reachable. **(HC: one-tap approval for now; full autonomy may come later.)**
- Anything that doesn't touch our stack never reaches the HC. **(HC)**
- Coverage can be verified. A silent feed, a failed scan or a broken pipeline raises its own issue, and a monthly drill proves the whole loop works.

## Goals, non-goals, anti-goals

**Goals:**
1. Watch every source that can tell us about a vulnerability or incident in what MPIAS runs:
   - GitHub security features;
   - advisory and exploit feeds;
   - mailing lists and vendor email in a monitored inbox;
   - RSS and status pages;
   - scans of our images, hosts and Cloudflare zones.
2. Triage each item against a maintained inventory of what we run and an exposure map. Drop what's irrelevant, rank the rest, and write it up with Claude.
3. Respond:
   - urgent items reach the HC as issues the same day;
   - simple patches take an express lane;
   - everything else follows the normal assess → execute → review flow (ADR-0012).
4. Harden the edge with Cloudflare's security features, and watch for those settings drifting.
5. Work through every existing finding on GitHub's [org security overview](https://github.com/orgs/mpimedia/security/overview). **(HC)** This covers:
   - the Dependabot alerts;
   - CodeQL and code scanning;
   - secret scanning;
   - the risk assessment.

   At launch the pipeline backfills them all through the same triage. Each is ranked by exploited × reachable and routed like a new item. This absorbs [ISS#45](https://github.com/mpimedia/mpi-application-workflows/issues/45)'s backlog triage. On 2026-10-20 that backlog stood at 111 open Dependabot alerts in the app suite, 184 in other repos, and the CodeQL findings.
6. Hunt for vulnerabilities in our own code with AI before attackers do.

**Non-goals (for now):**
- Buying Snyk, Socket, Aikido, StepSecurity or Ubuntu Pro. The HC chose to build, on 2026-10-21.
- DeepSeek, as a tool or a second opinion. **(HC: tabled; reconsider after the rest is done.)**
- Production deploys without the HC's approval.
- An agent running around the clock. Nothing agentic runs unattended today, and Theo's cron lives only while its session is open on the Mac mini. The pipeline runs as scheduled GitHub Actions; picking up issues remains the HC's or Theo's job.
- The ~95 film-title zones, until Garden serves them as static pages. **(HC)**
- The 10 org repos the mpi-automation App can't see. As far as the HC knows, none are live.

**Anti-goals** (these would make it a failure even if it technically works):
- **Noise.** The HC hearing about PHP, Windows or anything else we don't run. A digest nobody reads.
- **Write access to production from the monitor.** Every check of production reads only.
- **A personal token anywhere in the pipeline.**
- **False confidence.** A feed that stops quietly while the system looks green.
- **An agent patching production on its own from an alert.**
- **The pipeline becoming the easiest way into MPIAS.** Its credentials and inputs are guarded as carefully as production (part 9).

## Constraints

- **Credentials:** no personal tokens. GitHub access uses a dedicated mpi-security App (part 9), with mpi-automation still running the updaters. Anthropic access uses the existing org API account through workload identity federation, so no API key is stored (see "Credentials"). Other secrets live in org secrets or the 1Password service account.
- **Production:** read-only. The DigitalOcean token is read-only. The droplet check uses a no-sudo user.
- **App permissions:** add them only as needed. The HC approved these on 2026-10-21, for mpi-automation. Part 9 moves them to the dedicated App, which needs the HC's confirmation:
  - Dependabot alerts: read;
  - Code scanning alerts: read and write;
  - Issues: write on the watched repos.
- **Lanes:** ADR-0012 applies ([markaz ADR-0012](https://github.com/mpimedia/markaz/blob/main/docs/adr/0012-agent-operating-model.md)). This epic is **risk-high** because it adds workflows, credentials and new dependencies, and touches production hosts. The express lane changes how updater PRs reach `main`, which is a lanes-and-gates change. That needs an ADR-0012 amendment in markaz and adoption issues in garden and sfa (Decision 8; Harvest is being retired).
- **This repo's own rules apply** to any change in mpi-application-workflows:
  - inputs may only be added, never broken;
  - workflow filenames never change;
  - changes are tested from a consumer branch.

## Watched repos

**(HC, 2026-10-22):**
- markaz (formerly avails_server);
- sfa (formerly wpa_film_library);
- garden;
- mpi-infrastructure;
- mpi-application-workflows;
- mpi-security, once it exists.

**Retiring:**
- **Optimus and Harvest are being retired. (HC)**
- **Optimus** isn't deployed, so it's out of scope.
- **Harvest** is still running: harvest.mpimediagroup.com has droplets and a database. **(Claude's call):**
  - The pipeline keeps matching and alerting on it until its servers are shut down, because running code is attack surface whatever its future.
  - It gets no express lane, AI hunt or Cloudflare work beyond the zone-wide quick wins.
  - It leaves the inventory when mpi-infrastructure removes its stack.

**The other 10 org repos** the App can't see aren't live, as far as the HC knows. They're out of scope. Archiving them would make that explicit. **(Claude's suggestion, not part of this epic.)**

## Where it lives

- **A new private repo, `mpimedia/mpi-security`. (Claude's call; the HC creates the repo or approves its creation.)** It holds:
  - the pipeline code;
  - the inventory and exposure map;
  - the source list;
  - the triage prompts;
  - the runbook;
  - the summary issues.
- **Issues for findings go to the repo where the fix happens.** Each one is also listed in a tracking issue in mpi-security.
- **Changes in other repos go through those repos' normal PRs:**
  - Terraform and Ansible in mpi-infrastructure;
  - a new input on `update-gems.yml` / `update-packages.yml` in this repo;
  - environment protection settings in each app.
- **Language: Ruby, tested with RSpec. (Claude's call.)** It matches the team, and the apps' updater tooling is already Ruby.

## How it works

```
  sources ──► intake ──► normalize ──► match vs inventory+exposure ──► Claude triage ──► route
   (feeds,     (scheduled                (drop irrelevant silently)     (risk profile,     │
   inbox,       Actions)                                                 affected, fix)     │
   scans)                                                                                    ▼
                                                    urgent ──► issue in fix repo + email + Theo's sweep
                                                       │          └─► express lane (simple bump)
                                                       │               PR → CI → staging → HC tap → prod
                                                    soon  ──► issue in fix repo
                                                    later ──► Monday digest
                                                    none  ──► logged only, never shown
```

### 1. Sources

**Structured feeds (no AI needed to match):**

| Source | What it gives | Matched against |
|---|---|---|
| GitHub org security overview ([page](https://github.com/orgs/mpimedia/security/overview)): the same alerts, rolled up by repo, plus the code-security and secret risk assessments | Everything GitHub already knows about our repos. **Backfilled once at launch, then watched for changes. (HC)** | Repo |
| [CVE List (cvelistV5)](https://github.com/CVEProject/cvelistV5) and NVD API 2.0 | New CVEs as soon as they're published (cvelistV5 updates every few minutes); severity scores from NVD | Product and package names in the inventory |
| Org Dependabot alerts (`GET /orgs/mpimedia/dependabot/alerts`) | Gem and npm CVEs, already matched per repo by GitHub, plus malware alerts | Repo plus manifest |
| Code scanning alerts: CodeQL, plus Trivy SARIF from the image scan | Flaws in our code, and OS or gem packages in the images | Repo or image |
| Secret scanning alerts | Leaked credentials | Repo |
| GitHub Advisory DB (`/advisories`, `type=malware` and `ecosystem=actions`) | Malware, and compromised or tag-moved actions | Every `uses:` line in the watched repos |
| [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog) JSON | Exploited in the wild | CVE aliases on any item |
| VulnCheck KEV (free community tier) | Exploited in the wild; broader and often earlier than CISA | CVE aliases |
| EPSS (FIRST.org, daily CSV/API) | A daily probability that each CVE gets exploited | CVE aliases. A high EPSS counts as an exploitation signal. |
| GreyNoise community API | Whether attackers are scanning for a CVE right now | CVE aliases (urgent items) |
| Public exploits: Exploit-DB, Metasploit modules, GitHub proof-of-concept trackers (for example nomi-sec/PoC-in-GitHub) | A working exploit is public | CVE aliases |
| CISA advisories RSS | Government alerts and incident write-ups | Vendors and products |
| Debian Security Tracker and DSA | **Debian packages in our images** (`ruby:*-slim` is Debian-based) | Image package lists |
| endoflife.date API | End-of-life dates for Ruby, Rails, Node, Postgres, Ubuntu and Debian | Versions in the inventory |
| OSV (`Ubuntu:24.04`, plus a lockfile cross-check) | Droplet packages and kernel; a second opinion on lockfiles | Droplet package lists and lockfiles |
| Ubuntu USN JSON/RSS | Ubuntu security notices | Droplets (Ubuntu 24.04) |
| DigitalOcean API: `/v2/databases`, `/v2/databases/options` | Engine version, end-of-life dates, pending maintenance | The 8 managed Postgres clusters |
| Status pages: DigitalOcean, Blacksmith, Cloudflare, GitHub | Incidents | nyc1, Managed Databases, Droplets, our runners |
| Cert Spotter API **(HC)** | Certificates issued for our domains | Expected CAs and hostnames (kamal-proxy's Let's Encrypt renewals are expected) |
| Mozilla CA incident bugs (Bugzilla) | CA compromises like eMudhra | Our trust stores and the CAs we use |
| Cloudflare (read API) | Zone settings and security events | The hardening baseline (part 6) |

**Unstructured sources** (Claude decides relevance):
- RSS:
  - Rails security announcements;
  - ruby-lang.org news;
  - Node.js vulnerability feed;
  - PostgreSQL news;
  - security releases for Kamal, Puma and Thruster (GitHub release feeds);
  - Tailscale security bulletins;
  - security news, where incidents like eMudhra surface first: BleepingComputer, The Hacker News, Ars Technica security, SecurityWeek, Risky Business.
  - The builder may add researcher accounts on infosec.exchange (Mastodon) through their RSS feeds.
- **A monitored inbox: a Postmark inbound address for MPIAS. (HC: Postmark rather than Microsoft 365.)** It's subscribed to:
  - oss-security, the main public disclosure list for open-source projects. It's high volume, so the prefilter is strict;
  - ruby-security-ann;
  - rubyonrails-security;
  - debian-security-announce;
  - nodejs-sec;
  - ubuntu-security-announce;
  - vendor security and maintenance notices from DigitalOcean, Cloudflare, Tailscale, GitHub, 1Password, Postmark and AWS.
- **Cloudflare's certificate-transparency email can also go to the inbox. (Claude's call.)** Claude's triage can drop the expected renewals that made it too noisy to send to a person. Cert Spotter stays the primary certificate source.
- **Builder to verify:** how long Postmark keeps inbound messages, and whether the Messages API (`/messages/inbound`) is enough for polling. If it isn't, use Postmark's inbound webhook.

The builder may add sources. Each one needs an owner line in the source list, giving what it covers and why.

**Scanners we run ourselves.** All are free. Each runs SHA-pinned, either in the pipeline or as a CI addition through this repo's shared workflows. Findings go to code scanning as SARIF where possible, then through triage.

| Tool | What it catches | Where it runs |
|---|---|---|
| Brakeman, bundler-audit, `yarn npm audit` (existing) | Rails code flaws, gem CVEs, npm CVEs | `ci-rails.yml`, already in place; [ISS#50](https://github.com/mpimedia/mpi-application-workflows/issues/50) closes the markaz/sfa gap |
| CodeQL (existing, Code Security) | Code flaws | GitHub default setup |
| osv-scanner | A second opinion on lockfiles and images | Pipeline, daily |
| Trivy, plus Grype/Syft | Image OS and gem packages, secrets and misconfigurations in images; SBOMs | Pipeline, daily, on the deployed image per app |
| Trivy config (existing in mpi-infrastructure) | Terraform misconfigurations | mpi-infrastructure CI |
| zizmor and actionlint | Unsafe GitHub Actions workflows: injection, overly broad tokens, unpinned actions. This is the class behind the trivy-action and tj-actions compromises. | CI in every watched repo, and a weekly pipeline sweep |
| OpenSSF Scorecard | A security score for each repo: pinning, branch protection, token permissions | Pipeline, weekly |
| Gitleaks or TruffleHog | Secrets in git history, beyond GitHub's push protection | Pipeline, weekly full-history scan |
| Semgrep (community Ruby/Rails rules) | Code patterns that Brakeman and CodeQL miss | CI |
| testssl.sh and Mozilla Observatory | TLS and security-header configuration on our live public hostnames. Read-only requests. | Pipeline, weekly |
| OWASP ZAP baseline | Common web flaws | **Staging only**, weekly. Never production. |
| Cloudflare Security Center | Attack surface and misconfiguration insights for our zones | Read through the Cloudflare token (part 6) |

The builder picks between overlapping tools (Trivy vs. Grype, Gitleaks vs. TruffleHog) and may phase them in. The categories stay.

### 2. Inventory and exposure

A nightly job rebuilds `inventory.json` in mpi-security from the sources of truth:
- each watched repo's lockfiles (`Gemfile.lock`, Yarn 4 `yarn.lock`), `.tool-versions`, Dockerfile `FROM` lines and Kamal configs (hosts, accessories, proxy hosts);
- workflow `uses:` lines;
- `.terraform.lock.hcl` providers;
- DigitalOcean database engines;
- droplet package lists (part 3);
- Cloudflare zones.

Two files are **reviewed by hand** and changed only through PRs **(Claude's call)**:
- **`vendors.yml`:** every service we depend on (GitHub, Blacksmith, DigitalOcean, Cloudflare, Tailscale, 1Password, Postmark, AWS S3, Entra ID, the Elasticsearch host, Let's Encrypt, Honeybadger if used). A vendor's breach notice is relevant only if the vendor is listed here.
- **`exposure.yml`:** for each app and host, what an anonymous visitor can reach. The HC's starting list:
  - **Public, with applications behind them:**
    - mpimedia.com, watermelonpictures.com (Pro), darkskyfilms.com, mpiclassics.com;
    - mpistockfootage.com (plus mpistockfootagearchive.com, which sfa's Kamal config also serves).
  - **Staff only:** mpimediagroup.com (Pro) and mpistag.ing.
    - **Exception: `public.mpimediagroup.com` is public.** Markaz's External Sites feature uses it, so it counts as public. **(HC)**
  - Within each app, the public paths come first: Markaz's screening request forms, the public pages, webhooks and uploads. Admin areas behind login come next. Workers and build-time-only packages are the least exposed.
  - The managed databases count as **internet-reachable** until mpi-infrastructure [ISS#63](https://github.com/mpimedia/mpi-infrastructure/issues/63) closes. Today they accept connections from anywhere.

### 3. Triage

**Step 1: match, deterministically.**
- Packages and versions are checked against the inventory.
- CVE aliases are joined to KEV.
- `uses:` lines are checked against action advisories.
- Vendor names are checked against `vendors.yml`.
- Items for ecosystems we don't run (PHP, Java, Windows and so on) are dropped here and written to a log. They're never shown. **(HC)**

**Step 2: Claude reads and writes.** Claude handles:
- every unstructured item (email, RSS) that survives a cheap keyword prefilter;
- every matched structured item.

It sees the item, the matching inventory entries and the exposure map, and returns structured output:
- whether it's relevant;
- the evidence that it's being exploited;
- how reachable it is;
- the affected repos, files, versions and hosts;
- the fix, any mitigation, and the options;
- whether it qualifies for the express lane;
- its confidence.

Low-confidence results go to the digest, never to an urgent issue. The model choice and prompt design are the builder's (for example, Sonnet for screening and Opus for urgent write-ups). The spending cap is set on the Anthropic workspace.

**Urgency is exploited × reachable:**

| | Internet-reachable | Staff-only, internal or build-time |
|---|---|---|
| **Exploited** (KEV, malware, compromised action, vendor incident, public working exploit) | **urgent**: issue, email and express lane if eligible | **soon**: issue |
| **Not known to be exploited** | **soon**: issue (critical severity is always at least soon) | **later**: Monday digest |

**Always urgent:** a certificate we didn't expect for our domains, a compromised action we use, a CA distrust that affects our trust stores, a database engine within 90 days of end-of-life, or a droplet with a reboot pending for more than 48 hours. (The last two can be "soon" if the builder finds them noisy.)

### 4. Routing and the issue

- **Where it's filed:** in the repo where the fix happens.
  - Package and image findings go to the app repo.
  - Actions findings go to each repo that uses the action.
  - Host, DigitalOcean, Cloudflare, certificate and status findings go to mpi-infrastructure.
  - Pipeline findings go to mpi-security.
- **Labels:** `security`, plus `sev:urgent`, `sev:soon` or `sev:later`. The pipeline creates any missing label. The lane label stays an `/assess` decision, not the pipeline's.
- **Body sections:**
  - **Risk profile**, **How we're affected** and **What to do** (the HC's three).
  - **Sources**: a link for every claim.
  - **Timeline**: published, detected, filed, plus PR, staging and production times once the express lane runs.
  - A hidden marker, `<!-- secmon:<advisory-id>:<target> -->`, for deduplication. An item never files twice, and when an item changes the pipeline comments on the existing issue.
- **Email:** urgent issues trigger a Postmark email to the HC.
- **Theo:** Theo's sweep notices new `security` issues. Theo maintains the sweep, and checking that it covers every watched repo and matches the `security` label is a coordination item with Theo, not pipeline code. Until it does, the email covers the gap.
- **Digest:** every Monday an issue in mpi-security lists the "later" items. It reports open issues by severity, the time each fix took, express-lane timings and source health. Each new digest closes the previous one.

### 5. Response: the express lane

**When it applies:** the item is urgent, and the fix is a patch or minor bump of a gem or npm package within the same major version.

The flow builds on how the apps deploy today. In markaz's `deploy.yml`, a successful CI run on `main` deploys **staging** automatically through `workflow_run`. Production deploys only from a `workflow_dispatch` with a named SHA. `deploy-kamal.yml`'s guard ([PR#43](https://github.com/mpimedia/mpi-application-workflows/pull/43)) requires that SHA to be on `main` and ahead of the last successful production deploy. The express lane keeps that guard as it is.

1. **Trigger the updater for one package.** The pipeline dispatches the app's update workflow with that package as the target. This needs a new, non-breaking `only:` input on `update-gems.yml` and `update-packages.yml` in this repo.
2. **The App opens the upgrade PR,** referencing the issue, and CI runs.
3. **Review stands in for `/dep-review`.** A Claude check in Actions replaces it for this case: the lockfile diff touches only the target package (plus resolver-required transitive changes), no new dependency appears, and CI is green.
4. **The App merges the PR into `main`. (HC, 2026-10-22: yes.)** The `main` ruleset requires a PR and passing checks, with no required human review and no bypass actors, so no bypass is needed. The existing flow then deploys `main` to **staging**, as every merge already does.
5. **The HC approves production with one tap.**
   - The pipeline dispatches the production deploy with the merge commit's SHA, which passes the PR#43 guard.
   - The deploy job waits on a GitHub environment protection rule on `production`, with the HC as the required reviewer.
   - The HC approves from the GitHub mobile app.
   - Each app needs a `production` environment with that rule, and `deploy-kamal.yml` must set `environment:` on its production job. That's an added behaviour, not a breaking input change, and the builder confirms it.
6. **Rollback is one step:** a `workflow_dispatch` that runs a Kamal rollback for the app and environment.
7. **The pipeline rescans,** and closes the issue once the vulnerable version is gone everywhere, including what's deployed.
   - What's deployed is identified from GitHub's deployment records, which `deploy-kamal.yml` already writes with `deployments: write`. The pipeline then scans the image for that SHA.
   - `secmon` must not use the Docker socket, because that access is effectively root. **(Claude's call.)**
   - If the App can't read ghcr images, the builder asks the HC for a read-only registry credential rather than widening `secmon`.

Every step writes its timestamp to the issue timeline. The 60-minute target is measured, not assumed.

The express lane runs for markaz, sfa and garden. Harvest is being retired, and Optimus isn't deployed.

**ADR-0012 change needed:** steps 3 and 4 change how updater PRs reach `main`. A workflow's Claude check replaces the session's `/dep-review`, and the App merges. An amendment in markaz and adoption issues in the siblings come before the express lane goes live in any app. The builder drafts the amendment, and the HC approves it.

### 6. Hardening with Cloudflare

All changes go through Terraform in mpi-infrastructure, which already uses the Cloudflare provider. They are risk-high PRs. Nothing changes through the API by hand. **(Claude's call.)**

State on 2026-10-22, read with the "Cloudflare API - Claude" token:
- The account has 104 zones: 102 on Free and 2 on Pro (mpimediagroup.com and watermelonpictures.com).
- **DNSSEC is off on all 8 application zones.**
- **CAA records exist only on watermelonpictures.com.**
- Turnstile is already used for screening requests.
- The token can't read zone settings or WAF rules yet. The HC is asked to add Zone Settings Read, Zone WAF Read, Firewall Services Read and Account Rulesets Read.

Baseline for the 8 application zones:
- **DNSSEC on.**
- **CAA records:** our CAs only. That means Let's Encrypt for kamal-proxy, plus the CAs Cloudflare uses for Universal SSL. Get these right, or Cloudflare can't renew the edge certificates.
- **TLS:** SSL mode Full (strict), minimum TLS 1.2, Always Use HTTPS, and HSTS once it's stable.
- **WAF managed rules,** on the Free ruleset or Pro's full set.
- **Rate limits** on the public forms and logins.
- **Bot protection** where it doesn't break webhooks.
- **Turnstile** on every public form.
- **Cloudflare Access** in front of the staff-only domains, with Entra ID as the identity provider (the apps already use omniauth-entra-id). The free tier covers up to 50 users.
  - Access is set **per hostname, not across the whole zone.** `public.mpimediagroup.com` serves Markaz's External Sites to the public and must stay outside Access.
  - Webhook and health-check paths that outside services call need explicit bypass rules.
- **The origin accepts only Cloudflare.** Restrict the DigitalOcean web firewalls to Cloudflare's IP ranges, or move to Cloudflare Tunnel (1Password has tunnel tokens). Add Authenticated Origin Pulls.
- **Security Center** attack-surface scans.
- **`security.txt`.**

**Do the cheap, high-value items early,** in parallel with part 1 (DNSSEC, CAA, TLS settings). The eMudhra incident is exactly what CAA and certificate monitoring protect against.

**Drift monitoring:** a daily job reads the settings with a dedicated read-only token and files an issue in mpi-infrastructure when a zone falls below the baseline. It also summarises Cloudflare security events in the digest.

### 7. Hunting with AI

**Cut what's reachable first, then hunt for bugs. (HC pointed to this, 2026-10-22.)** The approach comes from Anthropic's ["Using Claude to reduce the attack surface of code"](https://www.anthropic.com/research/attack-surface-reduction) (Frontier Red Team, 2026-10-20). Restricting code that's reachable but unneeded, especially code that runs before authentication, makes unknown vulnerabilities less severe without finding each one first.

Claude runs the article's three passes on each app, adapted to Rails. The results become PRs that reduce what can be reached, filed as findings through the normal triage:

1. **Default configuration.** Find routes, engines, middleware and endpoints reachable in production that no intended feature uses. Candidates include:
   - Rails' built-in routes (Active Storage direct uploads and proxies, Action Mailbox conductor, health and info routes);
   - dashboards (GoodJob, Blazer) and their mounting and authentication;
   - debug and preview endpoints;
   - unused parsers and formats.
2. **Early reachability.** Find complex or security-sensitive work that runs before login:
   - parsing multipart uploads, XML (Nokogiri), images (libvips) and JSON;
   - webhooks;
   - the public screening forms.

   The fixes move work behind authentication or validation, or make features opt-in.
3. **Configuration interaction.** Find combinations of settings that quietly weaken a control, such as:
   - `force_ssl` and host authorization behind Cloudflare and kamal-proxy;
   - Devise and session options;
   - content security policy;
   - rate limiting;
   - Cloudflare zone settings interacting with app settings.

   Deny rules must fail closed.

**Changes are the HC's decision.** The article's own practice is that changes to anything non-default are left to a human, and our lanes require the HC for risk-high changes. **Check before building:** whether Anthropic's attack-surface skill, described in the article and being integrated with OSS-Scanner, is published and usable here. If so, use it rather than writing our own passes.

The same idea applies to infrastructure, and parts 4–6 already cover those changes:
- Cloudflare Access in front of the staff-only domains;
- an origin that accepts only Cloudflare;
- closing public access to the databases.

**Bug hunting, after the reachability passes: Cloudflare's [security-audit skill](https://github.com/cloudflare/security-audit-skill). (HC pointed to it, 2026-10-22.)**

It's MIT-licensed, and it's the starting point Cloudflare's own vulnerability-discovery harness grew from. It runs a six-phase audit:
1. reconnaissance and a coverage ledger;
2. hunting with isolated agents;
3. adversarial validation, where the checker is never the finder;
4. findings written in a schema;
5. independent re-verification;
6. a report.

Its output (`findings.json`, verdicts `confirmed` / `needs_validation` / `rejected`, validated against `report-schema.json`) feeds our triage directly:
- **`confirmed`** findings go through routing like any other item.
- **`needs_validation`** findings go to the digest.
- **`rejected`** findings are kept for the record only.

How we use it **(Claude's call)**:
- **Vendored into mpi-security at a reviewed commit,** starting from `c1c8a8c1471069fb0e188eeaff69b8e8db6564a8` (2026-09-14). It's never installed with `npx skills add` from `main`, because a skill is instructions to an agent holding tools, and that's a supply-chain path. Updates are PRs that a person reads.
- **It runs with no credentials beyond reading the target repo and writing to a scratch directory.** Its findings are text for our triage, never commands.
- **The sandbox rule it states.** The skill only executes target code inside an OS-enforced sandbox with no outside network. Otherwise it leaves a lead as `needs_validation`. In Actions that means a locked-down container on the runner. The builder decides whether to provide that, or accept `needs_validation` for anything that needs execution.
- **Ledgers and findings persist in mpi-security,** so runs add up. The README notes a single run finds roughly half of what repeated runs find.
- **Cadence:** a full run per app monthly, plus a focused run when a PR touches a public path in `exposure.yml`. It runs many parallel agents, so the Anthropic spending cap and the run schedule are set together.
- **It can run today, by hand,** in a Claude Code session on any of our repos, before the pipeline exists. That's an early win the HC can ask for at any time.

**Ongoing passes:**

- **Weekly, per app,** Claude reviews the code that `exposure.yml` marks public, then everything behind login, looking for exploitable flaws. It runs through the claude-code-action or the Agent SDK with the workflow's Anthropic identity.
- **On each merge to `main`,** a lighter review covers the diff, `/security-review`-style.
- **Testing never touches staging or production.** Any dynamic check runs against a copy of the app that CI builds inside the Actions runner.
- **Findings go through the same triage and routing.** Each one needs a concrete exploit path in the write-up. Speculative findings go to the digest.
- **Later, if the HC applies:** Anthropic's Cyber Verification Program Defense tier, launched 2026-10-06, for fewer refusals. The use case would be "our own Rails applications". The HC applies, and agents can't.
- DeepSeek is tabled. **(HC)**

### 8. Keeping it honest

- **Source health:** each source records its last successful fetch. A source silent for longer than its expected cadence opens an issue in mpi-security, and so does a failed scan.
- **Workflow failures** send Postmark notifications, as the other workflows do.
- **Monthly drill:** a synthetic advisory with a drill marker runs through matching, triage, filing and the express lane on **staging only**. The digest reports the time each step took.
- **Coverage check:** the digest lists which repos, images, hosts and zones were scanned that week, so a gap is visible.

### 9. Securing the pipeline itself

The pipeline reads untrusted text and holds credentials that merge PRs and start deploys, which makes it a target in its own right. **Every rule in this section is a phase 1 requirement, not a later improvement. (HC asked for the gaps; added 2026-10-22.)**

**Prompt injection.** Emails, RSS items, advisory descriptions and scanner output are attacker-controllable. A crafted item could try to hide a real alert, file a fake fix, or push a malicious package through the express lane.
- **The Claude triage step has no tools and no credentials.** It sees text and returns structured output against a strict schema, and code validates that output. Every write (issues, dispatches, merges, emails) happens in deterministic code after the Claude step.
- **Code decides express-lane eligibility, never Claude.** The package and patched version come from the advisory's structured data (GHSA or OSV), and the target version must be exactly the advisory's first patched version. Claude's prose can't add a package, a version or a repo.
- **Claude can't lower severity.** Claude can raise severity or relevance. Lowering anything code computed (KEV, malware, exploited × reachable) needs a reason, goes to the digest, and doesn't suppress the deterministic result. A false "not relevant" fails safe.
- **The inbox accepts only verified senders.** Postmark exposes SPF/DKIM/DMARC results, and a sender allowlist (list addresses and vendor domains) is checked against them. Anything else is dropped and counted in the digest.
- **Quoted outside text in an issue is fenced and labelled untrusted.** Theo's and the agents' instructions say to treat it as data. The runbook repeats this.
- **The monthly drill includes a prompt-injection case:** an allowlisted-looking email that tells the triage step to close or downgrade an item. It must fail.

**Credentials and blast radius.**
- **A dedicated GitHub App for the pipeline (working name `mpi-security`), separate from mpi-automation. (Claude's call; the HC creates it.)**
  - Its private key lives only in mpi-security's repo secrets, behind a protected environment. It is never an org secret, so no other repo's workflow can read it.
  - Its installation tokens are requested per job with the minimum `repositories` and `permissions` that job needs.
  - mpi-automation keeps running the updaters, as now.
  - The permissions the HC approved on 2026-10-21 for mpi-automation move to this App instead, plus whatever the express lane needs. The builder lists them for the HC.
- **mpi-security's own workflows** run zizmor and actionlint and pin every action to a SHA. They use `permissions: {}` by default and grant per job. A ruleset protects `main` and requires review of any workflow change, and CODEOWNERS covers `.github/` and the prompts.
- **The Anthropic workspace has a hard spending cap,** so a flood of junk input can't run up the bill. The prefilter and sender allowlist come first.

**The express lane as a supply-chain path.** An attacker could publish a malicious "security fix" and count on us to rush it in.
- The lane installs only the advisory's first patched version, never "latest".
- It refuses when that release is under 24 hours old **and** was published by a different owner than the previous release. The builder sets the exact rule; the point is to catch account takeovers.
- It relies on the lockfile's integrity data. Yarn 4 already records checksums. For gems, Bundler's lockfile `CHECKSUMS` section (Bundler 2.6+; the apps run Bundler 4) is turned on in each app.
- The existing one-week npm cooldown (`npmMinimalAgeGate: 1w`) still applies to normal updater runs. The express lane is the only way past it, and only for the advisory's exact version.

### 10. Beyond patching: detection, identity, domains and recovery

Patching covers known vulnerabilities. These cover a break-in, a stolen account and a bad day. **(Added 2026-10-22.)**

**Detecting a break-in.** All of these are read-only. The pipeline watches and files issues in the same routing:
- **GitHub audit log** (org, read through the API; Enterprise offers streaming): new personal tokens, App installs or permission changes, ruleset and branch protection changes, secret changes, new outside collaborators, deploy keys, repo visibility changes.
- **Audit logs from Cloudflare, DigitalOcean, Tailscale and 1Password:** new members, new API tokens, permission changes, DNS changes outside Terraform.
- **Droplets:** SSH and Tailscale SSH logins, and new or changed user accounts, read by the `secmon` check from journald/auth logs.
- **Apps:** bursts of failed logins, and spikes in 4xx/5xx or WAF blocks, from Cloudflare analytics.
- Anything unexpected is urgent.

**Identity posture.** A weekly check:
- two-factor enforced on the GitHub org, Cloudflare, DigitalOcean, the domain registrar(s), 1Password, Tailscale, Postmark and AWS;
- GitHub outside collaborators, deploy keys, the fine-grained token policy, and installed third-party Apps and OAuth apps with their permissions;
- the org's default `GITHUB_TOKEN` permission (currently `write`, per [ISS#45](https://github.com/mpimedia/mpi-application-workflows/issues/45)).

Where an API can't report something, the runbook lists it as a quarterly manual check for the HC.

**Domains and DNS** (all 104 zones, not just the 8 application zones):
- **Subdomain takeover:** records pointing at services we no longer own (old hosts, S3, SaaS CNAMEs), checked weekly with a takeover scanner (dnsReaper, or Nuclei's takeover templates).
- **The registrar side:** registrar lock and expiry dates for every domain, and DNSSEC delegation (part 6).
- **Email authentication:** SPF, DKIM and DMARC on every domain, including those that never send mail (`v=spf1 -all` and `p=reject`). This stops phishing emails sent in our name.

**What the internet sees.** Weekly:
- Shodan and Censys lookups (free tiers) for our IPs and domains;
- a light port scan of the droplets' public IPs and the database endpoints.

Anything open beyond 80/443 on the web droplets is urgent.

**Incident response and recovery.** The runbook has an incident section:
- who decides and who's told;
- how to cut access (revoke tokens, rotate keys, put Cloudflare into "under attack" mode, take a host off the internet);
- a **rotation list** for every credential: Rails master keys, database passwords, Kamal secrets, both GitHub Apps, and the Cloudflare, DigitalOcean, Postmark, Anthropic, Tailscale and 1Password service-account credentials;
- how to restore.

**A backup-restore drill every quarter** restores a managed Postgres backup (point-in-time) into a scratch cluster. A database left open to the internet makes this urgent.

**When the HC can't approve or a fix can't deploy:**
- **Virtual patching:** a temporary Cloudflare WAF custom rule that blocks the exploit pattern, filed with the issue and removed once the fix ships. Cloudflare's managed rules often add emergency rules for big CVEs, and the drift job reports them.
- **A backup approver.** The HC names one, who goes on the `production` environment's reviewer list for the express lane. **(HC to decide.)**

**Accepting a risk.** `risk-register.yml` in mpi-security lists each accepted finding with:
- the finding;
- the reason;
- the owner;
- an **expiry date**.

Accepted findings are muted until expiry, then come back. Nothing is dismissed without an entry. The digest lists entries expiring soon.

## Credentials

| Credential | How it's held | Scope |
|---|---|---|
| **mpi-security App (new, dedicated)** | Private key only in mpi-security repo secrets, behind a protected environment. **Never an org secret.** Installation tokens are scoped per job. | Dependabot alerts read, Code scanning alerts read/write, Issues write, Security events/audit log read, plus Contents, Pull requests and Actions where the express lane needs them (to dispatch and merge). The builder lists the exact set for the HC. |
| mpi-automation App | Existing org secret, unchanged | Keeps running the updaters, which open the express-lane PRs |
| Anthropic | The existing org API account through workload identity federation (GitHub OIDC to a Console service account, `id-token: write`). No stored key. **(HC: use the existing API access.)** | A dedicated workspace with a monthly spending cap |
| DigitalOcean | Existing 1Password item "DigitalOcean API: mpias-read-only" (Application Development vault), read through the 1Password service account | Read-only |
| Cloudflare | A new dedicated **read-only** token for the pipeline, kept in 1Password. Changes go only through Terraform with mpi-infrastructure's existing token. | Zone, DNS, settings, WAF and analytics read |
| Postmark | A server token with inbound read; the existing outbound notification setup stays | The inbound stream for the MPIAS address |
| Cert Spotter | A free SSLMate account; the key goes in 1Password **(HC)** | Our domains |
| Droplet check | Tailscale for CI under a tag that may only SSH to droplets as `secmon` (no sudo), created by Ansible | Read-only commands |

## Order of work

Each phase ships on its own, as one or more risk-high PRs. The order is **Claude's call**, and the HC may reorder.

| Phase | What ships | Depends on |
|---|---|---|
| 0 | Create the `mpi-security` repo and the **dedicated mpi-security App**; set up Anthropic federation and the hard spending cap; add the Cloudflare token's read scopes; create the Postmark inbound address | HC actions |
| 1 | Inventory, structured feeds (including the exploitation signals), matching, Claude write-ups, routing, issues, email, digest, source health, **a one-time backfill of every existing finding on the org security overview, and all of part 9's pipeline-safety rules** | Phase 0 |
| 1b | Cloudflare quick wins: DNSSEC, CAA, TLS settings, via Terraform | Cloudflare read scopes; runs alongside phase 1 |
| 2 | Inbox and RSS intake with Claude triage | Phase 1, Postmark inbound |
| 3 | Scanners (image scan, osv-scanner, zizmor/actionlint, Scorecard, secrets history, Semgrep, TLS/header checks, ZAP on staging), droplet `secmon` check, DigitalOcean, status pages, Cert Spotter | Phase 1, Tailscale tag, Cert Spotter key |
| 4 | Express lane: `only:` input, Claude review step, staging auto-deploy, production approval, rollback, timing, drill | Phase 1, ADR-0012 amendment approved |
| 5 | Rest of the Cloudflare baseline (WAF, rate limits, Access, origin lockdown) and drift monitoring | Phase 1b |
| 6 | AI hunt | Phase 1 |
| 7 | Part 10: break-in detection (audit logs, logins), identity posture, domains and DNS (takeover, registrar, SPF/DKIM/DMARC), the outside view, incident runbook and rotation list, the quarterly restore drill, virtual patching, the risk register | Phase 1. The incident runbook and restore drill may move earlier; the restore drill is cheap and the databases are exposed today. |
| — | Runbook (`docs/security-runbook.md` in mpi-security), grown with each phase | — |

## Left to the builder

- Script structure, models, prompts, the keyword prefilter, and where state lives. Issue markers are the deduplication source of truth. Fetch cursors can live in a committed state file or a `state` branch.
- Final source list and cadences. Hourly for the urgent check, with the digest on Mondays **(HC)**; the rest as each source warrants.
- The exact App permission additions for the express lane, listed for the HC before they're requested.
- Issue template wording, within the three required sections.
- Whether a Claude review step can stand in for `/dep-review` or needs a further check. Raise it in the ADR-0012 amendment.

## Open questions for the HC

- Who is the backup approver for production deploys when the HC can't be reached (part 10)?

## Related

- [ISS#45](https://github.com/mpimedia/mpi-application-workflows/issues/45): triage of the existing code-security backlog. Its findings now flow through this epic's phase 1 backfill.
- In this repo: [ISS#49](https://github.com/mpimedia/mpi-application-workflows/issues/49) (SHA-pin actions), [ISS#50](https://github.com/mpimedia/mpi-application-workflows/issues/50) (yarn audit), [ISS#51](https://github.com/mpimedia/mpi-application-workflows/issues/51) (stale repo names).
- In mpi-infrastructure: [ISS#63](https://github.com/mpimedia/mpi-infrastructure/issues/63) (databases have no trusted sources), [ISS#64](https://github.com/mpimedia/mpi-infrastructure/issues/64) (SHA-pin actions), [ISS#65](https://github.com/mpimedia/mpi-infrastructure/issues/65) (Docker auto-patching).
- markaz [ISS#2126](https://github.com/mpimedia/markaz/issues/2126) and sfa [ISS#2273](https://github.com/mpimedia/sfa/issues/2273): Node installed from unpinned node-build.
- Research: [the recommendation](https://github.com/mpimedia/mpi-application-workflows/issues/48#issuecomment-6320345925) and [the GitHub Advanced Security billing correction](https://github.com/mpimedia/mpi-application-workflows/issues/48#issuecomment-6326341353).
