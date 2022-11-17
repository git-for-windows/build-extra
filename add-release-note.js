#!/usr/bin/env node

const fs = require('fs')

/**
 * Adds an entry to the `ReleaseNotes.md` file
 *
 * The `type` parameter must be one of `feature` (referring to the "New
 * Features" section), `bug` (referring to the "Bug Fixes" section) or `blurb`
 * (referring to the space before the "New Features" and "Bug Fixes" sections).
 *
 * @param {string} type
 * @param {string} message
 */
const addReleaseNote = (type, message) => {
  const sections = {
    blurb: [],
    feature: [],
    bug: []
  }
  if (!sections[type]) throw new Error(`Unhandled type '${type}' (must be one of "${Object.keys(sections).join('", "')}")`)

  // Read in the file contents
  const path = `${__dirname}/ReleaseNotes.md`
  const contents = fs.readFileSync(path)

  const entries = contents.toString().split(/(\n## Changes since Git for Windows v)(\d+(?:\.\d+)*)( \()([A-Z][a-z]+ \d+[a-z]* \d{4})(\))/g)
  const [, currentVersion, currentDate ] = entries[0].match(/^# Git for Windows v(\d+(?:\.\d+)*) Release Notes\nLatest update: ([A-Z][a-z]+ \d+[a-z]* \d{4})/)
  const latestVersion = entries[2]
  const latestDate = entries[4]

  // If no section exists for the latest version yet, add one
  if (true && latestVersion !== currentVersion || latestDate !== currentDate) {
    entries.splice(1, 0, '\n## Changes since Git for Windows v', currentVersion, ' (', currentDate, ')', '\n')
  }

  // Parse the latest section
  let current = sections.blurb
  for (const line of entries[6].split('\n')) {
    if (line === '') continue
    if (line === '### New Features') current = sections.feature
    else if (line === '### Bug Fixes') current = sections.bug
    else current.push(line)
  }

  // Add the message to the section
  sections[type].push(type === 'blurb' ? message : `* ${message}`)

  // Put it all back together
  const blurb = sections.blurb.length ? `\n${sections.blurb.join('\n\n')}\n` : ''
  const feature = sections.feature.length ? `\n### New Features\n\n${sections.feature.join('\n')}\n` : ''
  const bug = sections.bug.length ? `\n### Bug Fixes\n\n${sections.bug.join('\n')}\n` : ''
  entries[6] = `\n${blurb}${feature}${bug}`

  // Write the updated `ReleaseNotes.md`
  fs.writeFileSync(path, entries.join(''))
}

const main = async () => {
  if (process.argv.length !== 4) {
    throw new Error(`Usage: ${process.argv[1]} ( blurb | feature | bug ) <message>\n`)
  }
  const [, , type, message] = process.argv
  addReleaseNote(type, message)
}

main().catch(e => {
  process.stderr.write(`${e.message}\n`)
  process.exit(1)
})