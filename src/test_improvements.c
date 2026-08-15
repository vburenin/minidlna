/* Standalone checks for path / caption / skip helpers. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "pathmatch.h"

static int failed;

static void
expect(int cond, const char *msg)
{
	if (!cond)
	{
		fprintf(stderr, "FAIL: %s\n", msg);
		failed++;
	}
}

int
main(void)
{
	expect(match_glob("*-sample.*", "movie-sample.mkv"), "sample suffix");
	expect(match_glob("*-trailer.*", "movie-trailer.mp4"), "trailer suffix");
	expect(!match_glob("*-sample.*", "sample-rate.mkv"), "not a sample");
	expect(match_glob("*.nfo", "Movie.nfo"), "nfo glob");
	expect(match_glob("foo?.mkv", "foo1.mkv"), "question mark");
	expect(!match_glob("foo?.mkv", "foo12.mkv"), "question mark length");

	expect(is_sample_filename("movie-sample.mkv"), "is sample dash");
	expect(is_sample_filename("movie_sample.avi"), "is sample underscore");
	expect(is_sample_filename("sample.mkv"), "is sample exact");
	expect(is_sample_filename("movie-trailer.mkv"), "is trailer");
	expect(!is_sample_filename("The Sample Movie.mkv"), "not sample in title");

	expect(caption_stem_matches("Movie", "Movie"), "exact caption");
	expect(caption_stem_matches("Movie", "Movie.en"), "lang 2");
	expect(caption_stem_matches("Movie", "Movie.eng"), "lang 3");
	expect(caption_stem_matches("Movie", "Movie.en.forced"), "lang forced");
	expect(caption_stem_matches("Movie", "Movie.forced"), "forced");
	expect(caption_stem_matches("Movie", "Movie.sdh"), "sdh");
	expect(!caption_stem_matches("Movie", "Movie2"), "different file");
	expect(!caption_stem_matches("Movie", "Movie.commentary.en"), "unknown tag");
	expect(!caption_stem_matches("Show", "Show.S01E01"), "episode leftover");

	if (failed)
	{
		fprintf(stderr, "%d test(s) failed\n", failed);
		return 1;
	}
	printf("test_improvements: ok\n");
	return 0;
}
