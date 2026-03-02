/**
 * Place this file at app/api/appcast/route.ts in your Next.js project.
 * Replace the sample release entries with data from your build pipeline.
 */
import { NextResponse } from 'next/server'

type Release = {
  version: string
  shortVersion: string
  pubDate: string
  notesURL: string
  downloadURL: string
  signature: string
  length: number
  minimumSystemVersion: string
  description: string
}

// Update this array during your CI release job.
const releases: Release[] = [
  {
    version: '2026030201',
    shortVersion: '0.5.0',
    pubDate: 'Mon, 02 Mar 2026 12:00:00 +0000',
    notesURL: 'https://glint.statictype.org/releases/0.5.0',
    downloadURL: 'https://downloads.statictype.org/Glint-0.5.0.zip',
    signature: 'BASE64_EDDSA_SIGNATURE_FROM_generate_appcast',
    length: 24576000,
    minimumSystemVersion: '13.0',
    description: 'Adds Sparkle-powered updates and various fixes.'
  }
]

const channelMeta = {
  title: 'Glint Updates',
  link: 'https://glint.statictype.org',
  description: 'Stable release channel for Glint.'
}

const rssHeader =
  '<?xml version="1.0" encoding="utf-8"?>' +
  '<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">'

export async function GET() {
  const items = releases
    .map((release) => {
      return `
        <item>
          <title>Glint ${release.shortVersion}</title>
          <link>${channelMeta.link}</link>
          <sparkle:releaseNotesLink>${release.notesURL}</sparkle:releaseNotesLink>
          <pubDate>${release.pubDate}</pubDate>
          <dc:creator>Glint</dc:creator>
          <sparkle:minimumSystemVersion>${release.minimumSystemVersion}</sparkle:minimumSystemVersion>
          <description><![CDATA[${release.description}]]></description>
          <enclosure
            url="${release.downloadURL}"
            sparkle:version="${release.version}"
            sparkle:shortVersionString="${release.shortVersion}"
            sparkle:edSignature="${release.signature}"
            length="${release.length}"
            type="application/octet-stream"
          />
        </item>`
    })
    .join('')

  const xml = `${rssHeader}
    <channel>
      <title>${channelMeta.title}</title>
      <link>${channelMeta.link}</link>
      <description>${channelMeta.description}</description>
      ${items}
    </channel>
  </rss>`

  return new NextResponse(xml, {
    headers: {
      'content-type': 'application/xml; charset=utf-8',
      'cache-control': 'no-cache'
    }
  })
}
