#!/usr/bin/env node

const { execFileSync } = require('child_process')
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

  const entries = contents.toString().split(/(\n## Changes since Git for Windows v)(\d+(?:\.\d+)*(?:-rc\d+)?(?:\(\d+\))?)( \()([A-Z][a-z]+ \d+[a-z]* \d{4})(\))/g)
  const [, currentVersion, currentDate ] = entries[0].match(/^# Git for Windows v(\d+(?:\.\d+)*(?:-rc\d+)?(?:\(\d+\))?) Release Notes\nLatest update: ([A-Z][a-z]+ \d+[a-z]* \d{4})/)
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

  // Remove any superseded entries
  if (type === 'feature') {
    const match = message.match(/^(Comes with \[[^\]]+ )(v|patch level)/)
    if (match) sections.feature = sections.feature.filter(e => !e.startsWith(`* ${match[1]}`))
  }

  // Add the message to the section
  if (type === 'feature' && message.startsWith('Comes with [Git v')) {
    // Make sure that the Git version is always reported first
    sections.feature.unshift(`* ${message}`)
  } else {
    sections[type].push(type === 'blurb' ? message : `* ${message}`)
  }

  // Put it all back together
  const blurb = sections.blurb.length ? `\n${sections.blurb.join('\n\n')}\n` : ''
  const feature = sections.feature.length ? `\n### New Features\n\n${sections.feature.join('\n')}\n` : ''
  const bug = sections.bug.length ? `\n### Bug Fixes\n\n${sections.bug.join('\n')}\n` : ''
  entries[6] = `\n${blurb}${feature}${bug}`

  // Write the updated `ReleaseNotes.md`
  fs.writeFileSync(path, entries.join(''))
}

const wrap = (text, columns) => text
  .split(new RegExp(`(.{0,${columns}}|\\S{${columns + 1},})(?:\\s+|$)`))
  .filter((_, i) => (i % 2) === 1)
  .join('\n')

const main = async () => {
  let doCommit = false
  let mayBeAlreadyThere = false
  while (process.argv.length > 2 && process.argv[2].startsWith('--')) {
    if (process.argv[2] === '--commit') {
     doCommit = true
    } else if (process.argv[2] == '--may-be-already-there') {
      mayBeAlreadyThere = true
    } else {
      throw new Error(`Unhandled argument '${process.argv[2]}`)
    }
    process.argv.splice(2, 1)
  }

  if (process.argv.length !== 4) {
    throw new Error(`Usage: ${process.argv[1]} ( blurb | feature | bug ) <message>\n`)
  }
  const [, , type, message] = process.argv
  addReleaseNote(type, message)

  if (doCommit) {
      if (mayBeAlreadyThere) {
        try {
          execFileSync('git', ['--no-pager', 'diff', '--exit-code', '--', 'ReleaseNotes.md'])
          return // no differences, exit
        } catch (e) {
          // There were differences, commit them
        }
      }

      const subject = `Add a release note${type !== 'blurb' ? ` (${type})` : ''}`
      const body = wrap(message, 72)
      console.log(execFileSync('git', [
        'commit', '-s', '-m', subject, '-m', body, '--', 'ReleaseNotes.md'
      ]).toString('utf-8'))
  }
}

main().catch(e => {
  process.stderr.write(`${e.message}\n`)
  process.exit(1)
})