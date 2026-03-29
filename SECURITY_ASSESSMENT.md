# Repository Privacy & Security Assessment

**Date:** February 9, 2026  
**Repository:** mpimedia/mpi-application-workflows  
**Assessment Type:** Public vs Private Repository Risk Analysis

## Executive Summary

This repository contains reusable GitHub Actions workflows for MPI Media projects. This assessment evaluates whether the repository can be made private while maintaining functionality, and assesses security risks of maintaining it as a public repository.

**Key Finding:** This repository **CAN** be made private and still function correctly for private repositories, but requires explicit configuration. The current public status poses **LOW to MODERATE** information disclosure risks.

---

## Current State Assessment

### Repository Purpose
- Contains 4 reusable GitHub Actions workflows (`workflow_call` type)
- Used by multiple MPI Media Rails applications
- Provides standardized CI/CD pipelines, security scanning, linting, and automated updates

### Current Workflows
1. **ci-rails.yml** - Full CI pipeline with security scanning, linting, and testing
2. **update-gems.yml** - Automated Ruby gem updates
3. **update-packages.yml** - Automated Node.js package updates
4. **check-indexes.yml** - Database migration index validation

### Current Visibility
- Repository is currently **PUBLIC**
- All workflow definitions are publicly accessible
- Used by private MPI Media application repositories

---

## Technical Requirements: Public vs Private

### GitHub Actions Reusable Workflow Requirements

#### If Repository Remains PUBLIC:
✅ **Works immediately** - Any repository (public or private) can call these workflows  
✅ **No additional configuration needed**  
✅ **Simple syntax:** `uses: mpimedia/mpi-application-workflows/.github/workflows/ci-rails.yml@main`

#### If Repository Becomes PRIVATE:
✅ **CAN WORK** - But requires explicit access configuration  
⚠️ **Configuration Required:**
   1. Navigate to: Repository Settings → Actions → General → Access
   2. Explicitly grant access to each private repository that needs to call workflows
   3. Alternative: Grant access to all repositories in the organization

📋 **Access Configuration Options:**
- Grant access to specific repositories individually
- Grant access to all repositories in the organization
- Grant access to repositories in the enterprise (if applicable)

**Important:** The calling repositories must be in the same GitHub organization (mpimedia) or you need GitHub Enterprise for cross-organization access.

---

## Security Risk Assessment

### Information Currently Exposed (PUBLIC)

#### ✅ LOW RISK - Acceptable Public Information
1. **Technology Stack:**
   - Ruby/Rails with RSpec
   - PostgreSQL database
   - Node.js with Yarn
   - Elasticsearch (optional)
   - Standard open-source tools (RuboCop, Brakeman, bundler-audit)

2. **CI/CD Practices:**
   - Security scanning approach (Brakeman, bundler-audit, importmap/yarn audit)
   - Linting standards (RuboCop)
   - Test framework (RSpec)
   - Build processes

3. **Third-party Services:**
   - GitHub Actions (public knowledge)
   - Postmark API endpoint for notifications (public API endpoint)
   - PostgreSQL configuration (generic, no credentials)

#### ⚠️ MODERATE RISK - Information Disclosure Concerns

1. **Infrastructure Patterns:**
   - Reveals MPI Media uses specific versions/patterns
   - Shows exact CI pipeline structure
   - Discloses database setup patterns

2. **Secret Names Exposed:**
   ```
   - POSTMARK_NOTIFICATIONS_SMTP_TOKEN
   - WORKFLOW_FROM_EMAIL
   - WORKFLOW_TO_EMAIL
   - RAILS_MASTER_KEY
   ```
   **Note:** Secret *names* are visible, but *values* are NOT exposed (properly using `secrets.*` syntax)

3. **Organization Structure:**
   - Confirms "mpimedia" organization name
   - Reveals "MPI Media" as organization name
   - Shows internal tool/process standardization

4. **Testing Environment:**
   - PostgreSQL connection details (localhost, test credentials - not sensitive)
   - Elasticsearch version reading from `.tool-versions`
   - Service architecture hints

#### ✅ NO RISK - Properly Protected

1. **Secrets:** All sensitive values properly reference `${{ secrets.* }}`
2. **No Hardcoded Credentials:** No passwords, tokens, or API keys in code
3. **No Business Logic:** No proprietary algorithms or business rules
4. **No Data:** No customer data, PII, or sensitive business information

---

## Risk Analysis Summary

### If Repository Remains PUBLIC

**Advantages:**
- ✅ Zero configuration - works immediately with all calling repositories
- ✅ Easier maintenance - no access management needed
- ✅ Simpler onboarding for new projects
- ✅ Standard open-source pattern

**Risks:**
- ⚠️ Competitors/attackers can study your CI/CD patterns
- ⚠️ Infrastructure and tooling choices are visible
- ⚠️ Secret names are exposed (though values are protected)
- ⚠️ Could reveal organizational structure and practices
- ⚠️ Provides reconnaissance information for potential attackers

**Overall Public Risk Level:** 🟡 **LOW to MODERATE**

### If Repository Becomes PRIVATE

**Advantages:**
- ✅ Conceals internal CI/CD practices from public view
- ✅ Protects organizational tooling decisions
- ✅ Reduces reconnaissance surface for attackers
- ✅ Better aligns with "internal use only" statement in README

**Disadvantages:**
- ⚠️ Requires explicit access configuration for each repository
- ⚠️ Additional maintenance overhead for access management
- ⚠️ More complex onboarding for new projects
- ⚠️ Need to manage access when adding new repositories

**Overall Private Risk Level:** 🟢 **LOW** (only operational overhead)

---

## Recommendations

### Option 1: Make Repository Private (RECOMMENDED)

**Rationale:**
- Follows principle of least privilege
- Aligns with "Internal use only - MPI Media" statement in README
- No legitimate reason for public visibility
- Minimal operational overhead for small organization

**Implementation Steps:**

1. **Pre-Migration Preparation:**
   ```
   - Document all repositories currently using these workflows
   - Verify all calling repos are in mpimedia organization
   - Schedule change during low-activity period
   ```

2. **Make Repository Private:**
   ```
   - Go to: Repository Settings → General → Danger Zone
   - Click "Change visibility" → "Make private"
   ```

3. **Configure Access:**
   ```
   - Go to: Repository Settings → Actions → General
   - Under "Access", select one of:
     a) "Accessible from repositories in the 'mpimedia' organization" (RECOMMENDED)
     b) List specific repositories individually
   ```

4. **Verify Functionality:**
   ```
   - Test workflows in a calling repository
   - Monitor first few workflow runs for access issues
   - Update documentation if needed
   ```

5. **Update Documentation:**
   ```
   - Update README.md to reflect private status
   - Document access requirements for new projects
   ```

**Estimated Effort:** 1-2 hours (including testing)  
**Risk of Migration:** 🟢 **LOW** (easily reversible if issues arise)

### Option 2: Keep Repository Public

**Rationale:**
- Current setup works well
- Information exposed is relatively benign
- No highly sensitive information disclosed
- Simplest operational model

**Recommended Actions if Staying Public:**
1. ✅ Accept the information disclosure as acceptable risk
2. ✅ Ensure all secrets remain properly configured (currently correct)
3. ✅ Remove "Internal use only" statement from README (contradicts public status)
4. ✅ Consider this as an open-source contribution to the community
5. ✅ Regularly audit for any sensitive information additions

---

## Security Best Practices (Current Status)

### ✅ Currently Implemented Correctly
1. All sensitive values use `${{ secrets.* }}` - no hardcoded credentials
2. Secrets inherited from calling repositories using `secrets: inherit`
3. No business logic or proprietary code exposed
4. Standard, well-known tools and practices used
5. Generic PostgreSQL test credentials (postgres/postgres) - appropriate for CI

### 🔒 Additional Security Recommendations
1. **Regular Secret Rotation:** Ensure POSTMARK_NOTIFICATIONS_SMTP_TOKEN is rotated periodically
2. **Secret Scanning:** Enable GitHub secret scanning on calling repositories
3. **Access Review:** Periodically review which repositories have access (if made private)
4. **Dependency Updates:** Continue using update-gems and update-packages workflows
5. **Audit Logging:** Monitor GitHub Actions logs for unauthorized access attempts

---

## Decision Matrix

| Factor | Keep Public | Make Private |
|--------|-------------|--------------|
| **Operational Simplicity** | ✅ Excellent | ⚠️ Good (requires access mgmt) |
| **Security Posture** | ⚠️ Adequate | ✅ Strong |
| **Information Control** | ❌ Limited | ✅ Complete |
| **Maintenance Overhead** | ✅ Minimal | ⚠️ Low-Moderate |
| **Alignment with Policy** | ❌ "Internal use" label suggests private | ✅ Matches intent |
| **Reversibility** | ✅ Easy to make private later | ✅ Easy to make public later |
| **Cost** | ✅ Free | ✅ Free (included in organization) |

---

## Conclusion

**Primary Recommendation:** 🎯 **Make the repository PRIVATE**

**Reasoning:**
1. No legitimate business need for public visibility
2. Reduces information available to potential attackers
3. Aligns with "Internal use only" designation
4. Minimal operational overhead (one-time configuration)
5. GitHub Actions fully supports private reusable workflows
6. Can always be made public again if needed

**Alternative:** If organizational preference is to keep it public, the current risk level is acceptable as no highly sensitive information is exposed, but the "Internal use only" language should be removed from the README to avoid confusion.

---

## Next Steps

### Immediate Actions (If Making Private)
1. [ ] Review and approve this assessment
2. [ ] List all repositories currently using these workflows
3. [ ] Schedule change window (suggest: after current CI runs complete)
4. [ ] Make repository private
5. [ ] Configure organization-wide access
6. [ ] Test with one repository
7. [ ] Verify all calling repositories still function
8. [ ] Update README.md to document private status requirements

### Ongoing Actions
1. [ ] Implement quarterly access reviews (if private)
2. [ ] Maintain secret rotation schedule
3. [ ] Monitor for any sensitive information additions
4. [ ] Keep workflows updated with security best practices

---

## Appendix: Testing Checklist

If proceeding with making the repository private, test these scenarios:

- [ ] CI workflow runs successfully in a calling private repository
- [ ] Update-gems workflow runs successfully
- [ ] Update-packages workflow runs successfully  
- [ ] Check-indexes workflow runs successfully
- [ ] Secrets properly inherit from calling repository
- [ ] Elasticsearch variant works correctly
- [ ] Notification failures are sent correctly
- [ ] New repositories can be granted access easily

---

*Assessment completed by: GitHub Copilot*  
*For questions or clarifications, please comment on the associated issue.*
