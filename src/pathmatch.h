/* Shared path / filename matchers (also used by src/test_improvements.c). */
#ifndef __PATHMATCH_H__
#define __PATHMATCH_H__

#include <ctype.h>
#include <string.h>

static inline int
match_glob(const char *pat, const char *name)
{
	if (!pat || !name)
		return 0;
	while (*pat)
	{
		if (*pat == '*')
		{
			while (*pat == '*')
				pat++;
			if (!*pat)
				return 1;
			for (; *name; name++)
			{
				if (match_glob(pat, name))
					return 1;
			}
			return 0;
		}
		if (*pat == '?')
		{
			if (!*name)
				return 0;
			pat++;
			name++;
			continue;
		}
		if (tolower((unsigned char)*pat) != tolower((unsigned char)*name))
			return 0;
		if (!*name)
			return 0;
		pat++;
		name++;
	}
	return *name == '\0';
}

/* Video basename (no dir, no ext) vs caption basename (no dir, no ext).
 * Accepts Movie, Movie.en, Movie.eng, Movie.forced, Movie.en.forced, Movie.sdh. */
static inline int
caption_stem_matches(const char *video_stem, const char *cap_stem)
{
	size_t vlen, clen;
	const char *rest;
	int segs, i;

	if (!video_stem || !cap_stem || !video_stem[0] || !cap_stem[0])
		return 0;
	vlen = strlen(video_stem);
	clen = strlen(cap_stem);
	if (clen < vlen)
		return 0;
	if (strncasecmp(cap_stem, video_stem, vlen) != 0)
		return 0;
	if (clen == vlen)
		return 1;
	if (cap_stem[vlen] != '.')
		return 0;
	rest = cap_stem + vlen + 1;
	/* Up to three dotted tags: lang (2–3), forced, sdh, hi, cc, default. */
	for (segs = 0; *rest && segs < 3; segs++)
	{
		const char *dot = strchr(rest, '.');
		size_t n = dot ? (size_t)(dot - rest) : strlen(rest);
		int known = 0;

		if (n == 0)
			return 0;
		if (n <= 3)
		{
			known = 1;
			for (i = 0; i < (int)n; i++)
			{
				if (!isalpha((unsigned char)rest[i]))
				{
					known = 0;
					break;
				}
			}
		}
		if (!known && n <= 10)
		{
			static const char *tags[] = {
				"forced", "sdh", "hi", "cc", "default", "hearing", NULL
			};
			for (i = 0; tags[i]; i++)
			{
				if (strlen(tags[i]) == n && strncasecmp(rest, tags[i], n) == 0)
				{
					known = 1;
					break;
				}
			}
		}
		if (!known)
			return 0;
		rest = dot ? dot + 1 : rest + n;
		if (!dot)
			break;
	}
	return *rest == '\0';
}

static inline int
is_sample_filename(const char *base)
{
	if (!base || !base[0])
		return 0;
	if (match_glob("sample.*", base) || match_glob("trailer.*", base))
		return 1;
	if (match_glob("*-sample.*", base) || match_glob("*_sample.*", base) ||
	    match_glob("*.sample.*", base))
		return 1;
	if (match_glob("*-trailer.*", base) || match_glob("*_trailer.*", base) ||
	    match_glob("*.trailer.*", base))
		return 1;
	return 0;
}

#endif
