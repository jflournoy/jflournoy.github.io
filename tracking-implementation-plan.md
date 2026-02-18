# Implementation Plan: Add Simple Analytics Tracking to Demo Sites

## Summary

Add Simple Analytics tracking to 6 demo sites by modifying source configs and templates (not generated HTML). Document tracking in each CLAUDE.md for future builds.

**Quick Status:**
- ✅ Already have tracking: agent-stratify-demo, image-gen-pipe-v2
- 📝 Config-based (add to config files): llm-workings, terrain-maker_v2, no-silver-bullets
- 📝 Template-based (update template + add CLAUDE.md): garmin-analysis-v2, image-organizer, phd-unemployment-model

## Context

The user wants to add Simple Analytics tracking to all demo sites linked from [projects.qmd](projects.qmd). Currently, only the main johnflournoy.science site has the tracking code (`<script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>`). This tracking code provides privacy-first analytics without cookies.

**Key requirements:**
1. Modify source files/configs that generate HTML (not generated HTML directly)
2. Document tracking in each project's CLAUDE.md
3. Build locally → commit docs/ → push (GitHub Pages serves automatically)

**Tracking script:**
```html
<script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>
```

## Current Status

Investigation reveals:
- ✅ **agent-stratify-demo** (Wealth Strat ABM) - Already has tracking in [index.html:115](agent-stratify-demo/index.html#L115)
- ✅ **image-gen-pipe-v2** (Image Gen Pipeline) - Already has tracking in [public/demo.html:9](image-gen-pipe-v2/public/demo.html#L9)
- ⏸️ **story-time** - Not deployed yet (skip)

## Deployment Architecture

All demo projects are separate GitHub repos under jflournoy/* with `docs/` folders. GitHub Pages automatically serves these at `johnflournoy.science/repo-name/`.

**Deployment flow:**
1. Build locally (Quarto, Python, VitePress, etc.)
2. Commit generated `docs/` folder
3. Push to GitHub
4. GitHub Pages serves automatically

**Two deployment approaches:**

### Automated via GitHub Actions
These build and deploy automatically when code is pushed:

1. **llm-workings** → johnflournoy.science/llm-workings/
   - Auto-builds VitePress docs via `.github/workflows/deploy-docs.yml`

2. **terrain-maker_v2** → johnflournoy.science/terrain-maker_v2/
   - Auto-builds Sphinx docs via `.github/workflows/docs.yml`

### Manual Local Builds
These require building locally and committing `docs/`:

3. **phd-unemployment-model** → johnflournoy.science/phd-unemployment-model/
4. **garmin-analysis-v2** → johnflournoy.science/garmin-analysis/
5. **no-silver-bullets** → johnflournoy.science/no-silver-bullets/
6. **image-organizer** → johnflournoy.science/image-organizer/

## Build Process Findings

### Projects with Automated GitHub Pages Deployments

| Project | Build Tool | Source | Output | Config File | Workflow |
|---------|-----------|--------|--------|-------------|----------|
| **llm-workings** | VitePress | `docs/*.md` | `docs/.vitepress/dist/` | `docs/.vitepress/config.ts` | `deploy-docs.yml` |
| **terrain-maker_v2** | Sphinx | `docs/source/*.rst` + docstrings | `docs/build/html/` | `docs/source/conf.py` | `docs.yml` |

### Projects with Generated HTML but No Deployment Workflows

| Project | Build Tool | Source | Generated Output | Build Script/Config |
|---------|-----------|--------|------------------|---------------------|
| **phd-unemployment-model** | Quarto | `reports/*.qmd` | `docs/index.html` (8.8MB) | No _quarto.yml found |
| **garmin-analysis-v2** | Python | `docs/*.md` | `docs/*.html` | `docs/convert_to_html.py` |
| **no-silver-bullets** | Quarto | `index.qmd`, `analyses.qmd` | `docs/` | `_quarto.yml` |
| **image-organizer** | Unknown | Unknown | `docs/*.html` | TBD |

### Projects Already With Tracking

| Project | Tracking Location | Notes |
|---------|------------------|-------|
| **agent-stratify-demo** | `index.html:115` | Vite build source |
| **image-gen-pipe-v2** | `public/demo.html:9` | Node.js static files |

## Implementation Approach

### 1. llm-workings (VitePress Documentation)

**Deployment:** ✅ Automated via GitHub Actions → https://jflournoy.github.io/llm-workings/

**Source modification:**
- File: `/home/jflournoy/code/llm-workings/docs/.vitepress/config.ts`
- Add to `head` configuration array:
```typescript
head: [
  ['script', {
    async: '',
    src: 'https://scripts.simpleanalyticscdn.com/latest.js'
  }]
]
```

**CLAUDE.md addition:**
- Document that Simple Analytics tracking is configured in `.vitepress/config.ts`
- Note: Automatically included in all pages during VitePress build

**Verification:**
- Build: `cd llm-workings && npm run docs:build`
- Check: `grep -r "simpleanalyticscdn" docs/.vitepress/dist/`
- Test: Visit https://jflournoy.github.io/llm-workings/ and check page source

---

### 2. terrain-maker_v2 (Sphinx Documentation)

**Deployment:** ✅ Automated via GitHub Actions → https://jflournoy.github.io/terrain-maker_v2/

**Source modification:**
- File: `/home/jflournoy/code/terrain-maker_v2/docs/source/conf.py`
- Add after other configurations:
```python
# Simple Analytics tracking
html_js_files = [
    ('https://scripts.simpleanalyticscdn.com/latest.js', {'async': 'async'}),
]
```

**CLAUDE.md addition:**
- Document that Simple Analytics tracking is configured in `docs/source/conf.py`
- Note: Automatically included in all Sphinx-generated pages

**Verification:**
- Build: `cd terrain-maker_v2/docs && make html` (or via workflow)
- Check: `grep -r "simpleanalyticscdn" docs/build/html/`
- Test: Visit https://jflournoy.github.io/terrain-maker_v2/ and check page source

---

### 3. garmin-analysis-v2 (Python HTML Generation)

**Deployment:** ✅ Manual build → commit docs/ → GitHub Pages at johnflournoy.science/garmin-analysis/

**Source modification:**
- File: `/home/jflournoy/code/garmin-analysis-v2/docs/convert_to_html.py`
- Add tracking script to HTML template (in the `<head>` section)
- This script generates all HTML files in docs/ from markdown

**Build process:**
- Command: `npm run generate-docs` or `uv run python -m docs.generate_docs`
- Update the custom HTML template
- Regenerate docs/
- Commit and push docs/ folder

**CLAUDE.md addition:**
```markdown
## Analytics Tracking

**CRITICAL:** All HTML pages MUST include Simple Analytics tracking.

The tracking script is configured in `docs/convert_to_html.py` HTML template:
```html
<script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>
```

**When generating or modifying HTML:**
- Always ensure this script is present in the `<head>` section of the template
- Run `npm run generate-docs` to rebuild all HTML files
- Verify tracking is present: `grep -r "simpleanalyticscdn" docs/`
```

---

### 4. no-silver-bullets (Quarto Manuscript)

**Deployment:** ✅ Manual build → commit docs/ → GitHub Pages at johnflournoy.science/no-silver-bullets/

**Source modification:**
- File: `/home/jflournoy/code/no-silver-bullets/_quarto.yml`
- Add under `format: html:` section:
```yaml
format:
  html:
    toc: true
    include-in-header:
      - text: |
          <script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>
```

**Build process:**
- Render with `quarto render` or Docker command from main johnflournoy.science CLAUDE.md
- Commit and push docs/ folder

**CLAUDE.md addition:**
```markdown
## Analytics Tracking

Simple Analytics tracking is configured in `_quarto.yml` under `format: html: include-in-header`.
Tracking script is automatically included in all rendered HTML pages.
```

---

### 5. phd-unemployment-model (Quarto Reports)

**Deployment:** ✅ Manual build → commit docs/ → GitHub Pages at johnflournoy.science/phd-unemployment-model/

**Findings:**
- `docs/index.html` generated by Quarto 1.5.57 (confirmed via meta tag)
- One specific report generates docs/index.html
- Has `reports/*.qmd` source files

**Approach:**
1. Find which .qmd file generates docs/index.html
2. Add tracking to that .qmd file's YAML frontmatter:
```yaml
---
format:
  html:
    include-in-header:
      - text: |
          <script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>
---
```

**CLAUDE.md addition:**
```markdown
## Analytics Tracking

Simple Analytics tracking is configured in the YAML frontmatter of the report that generates `docs/index.html`.
Tracking script is automatically included when rendering with `quarto render`.
```

---

### 6. image-organizer (Documentation Site)

**Deployment:** ✅ Manual build → commit docs/ → GitHub Pages at johnflournoy.science/image-organizer/

**Findings:**
- `docs/` contains markdown documentation (AGENT_PATTERNS.md, API_SETUP.md, etc.)
- HTML files (index.html, showcase.html, documentation.html) likely generated from markdown
- Similar structure to garmin-analysis-v2

**Approach:**
1. Find HTML generation script (likely Python markdown-to-HTML converter)
2. Add tracking to HTML template (in the `<head>` section)
3. Update custom HTML template
4. Regenerate docs/ HTML files
5. Commit and push

**CLAUDE.md addition:**
```markdown
## Analytics Tracking

**CRITICAL:** All HTML pages MUST include Simple Analytics tracking.

The tracking script is configured in the HTML generation template:
```html
<script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>
```

**When generating or modifying HTML:**
- Always ensure this script is present in the `<head>` section of the template
- Run the docs generation script to rebuild all HTML files
- Verify tracking is present: `grep -r "simpleanalyticscdn" docs/`
```

## Recommended Implementation Sequence

### Phase 1: Config-Based Projects (Automated Deployments)
These have automated workflows - just modify config and push:

1. **llm-workings** (VitePress)
   - Modify `docs/.vitepress/config.ts`
   - Add to CLAUDE.md
   - Push to trigger workflow

2. **terrain-maker_v2** (Sphinx)
   - Modify `docs/source/conf.py`
   - Add to CLAUDE.md
   - Push to trigger workflow

### Phase 2: Quarto Projects (Manual Builds)
Add tracking to YAML configs:

3. **no-silver-bullets** (Quarto manuscript)
   - Modify `_quarto.yml`
   - Add to CLAUDE.md
   - Build locally and commit docs/

4. **phd-unemployment-model** (Quarto report)
   - Find .qmd file that generates docs/index.html
   - Add tracking to YAML frontmatter
   - Add to CLAUDE.md
   - Build locally and commit docs/

### Phase 3: Custom HTML Generators (Template-Based)
Update HTML templates + add CLAUDE.md instructions:

5. **garmin-analysis-v2** (Python HTML gen)
   - Modify `docs/convert_to_html.py` template
   - Add CRITICAL instructions to CLAUDE.md
   - Rebuild with `npm run generate-docs`
   - Commit docs/

6. **image-organizer** (Custom HTML gen)
   - Find and modify HTML generation template
   - Add CRITICAL instructions to CLAUDE.md
   - Rebuild HTML files
   - Commit docs/

## Critical Files to Modify

| Project | File | Type | Action |
|---------|------|------|--------|
| llm-workings | `docs/.vitepress/config.ts` | VitePress config | Add `head` array with script |
| terrain-maker_v2 | `docs/source/conf.py` | Sphinx config | Add `html_js_files` entry |
| no-silver-bullets | `_quarto.yml` | Quarto config | Add `include-in-header` |
| phd-unemployment-model | `.qmd` file (TBD which one) | Quarto frontmatter | Add `include-in-header` to YAML |
| garmin-analysis-v2 | `docs/convert_to_html.py` | Python template | Add script to `<head>` in template |
| image-organizer | HTML gen template (TBD) | Template file | Add script to `<head>` in template |

### CLAUDE.md Documentation

For each project above, add or update CLAUDE.md with:
```markdown
## Analytics Tracking

Simple Analytics tracking is configured in [config file]. The tracking script is automatically included in all generated pages.

When building/rendering, the script will be present in the output HTML.
```

## Verification Steps

For each modified project:

1. **Build locally:**
   - VitePress: `npm run docs:build`
   - Sphinx: `cd docs && make html`
   - Python: `npm run generate-docs`
   - Quarto: Docker render command

2. **Verify script present:**
   ```bash
   grep -r "simpleanalyticscdn" <output-directory>/
   ```

3. **Test in browser** (after deployment):
   - Visit demo URL
   - View page source
   - Verify `<script async src="https://scripts.simpleanalyticscdn.com/latest.js"></script>` is present

## Post-Implementation Steps

After adding tracking to source files:

1. **Build locally** for each project (commands in Implementation Approach above)
2. **Verify tracking** in generated HTML: `grep -r "simpleanalyticscdn" docs/`
3. **Commit changes** (source files + regenerated docs/) with descriptive message
4. **Push to GitHub** - Pages will update automatically
5. **Test in browser** - View source on live site to confirm script is present
