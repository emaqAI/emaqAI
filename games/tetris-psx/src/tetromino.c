#include "tetromino.h"

/* Shapes are given per-rotation as 4x4 grids ('#' = filled), matching the
 * standard SRS spawn orientations. */
static const char *SHAPES[PIECE_COUNT][ROTATION_COUNT] = {
	/* I */
	{
		"....####........",
		"..#...#...#...#.",
		"........####....",
		".#...#...#...#.."
	},
	/* O */
	{
		".##..##.........",
		".##..##.........",
		".##..##.........",
		".##..##........."
	},
	/* T */
	{
		".#..###.........",
		".#...##..#......",
		"....###..#......",
		".#..##...#......"
	},
	/* S */
	{
		".##.##..........",
		".#...##...#.....",
		".....##.##......",
		"#...##...#......"
	},
	/* Z */
	{
		"##...##.........",
		"..#..##..#......",
		"....##...##.....",
		".#..##..#......."
	},
	/* J */
	{
		"#...###.........",
		".##..#...#......",
		"....###...#.....",
		".#...#..##......"
	},
	/* L */
	{
		"..#.###.........",
		".#...#...##.....",
		"....###.#.......",
		"##...#...#......"
	}
};

void tetromino_get_cells(PieceType type, int rotation, Cell out[PIECE_CELLS])
{
	const char *shape = SHAPES[type][rotation & 3];
	int found = 0;

	for (int i = 0; i < 16 && found < PIECE_CELLS; i++) {
		if (shape[i] == '#') {
			out[found].x = (int8_t)(i % 4);
			out[found].y = (int8_t)(i / 4);
			found++;
		}
	}
}

int tetromino_color_index(PieceType type)
{
	return (int)type;
}

/* Standard SRS wall-kick tables (JLSTZ pieces share one table, I piece has
 * its own, O piece never needs kicks). Index is rotation state pair
 * 0->1, 1->0, 1->2, 2->1, 2->3, 3->2, 3->0, 0->3. */
static const Cell JLSTZ_KICKS[8][5] = {
	{{0,0},{-1,0},{-1,1},{0,-2},{-1,-2}},   /* 0->1 */
	{{0,0},{1,0},{1,-1},{0,2},{1,2}},       /* 1->0 */
	{{0,0},{1,0},{1,-1},{0,2},{1,2}},       /* 1->2 */
	{{0,0},{-1,0},{-1,1},{0,-2},{-1,-2}},   /* 2->1 */
	{{0,0},{1,0},{1,1},{0,-2},{1,-2}},      /* 2->3 */
	{{0,0},{-1,0},{-1,-1},{0,2},{-1,2}},    /* 3->2 */
	{{0,0},{-1,0},{-1,-1},{0,2},{-1,2}},    /* 3->0 */
	{{0,0},{1,0},{1,1},{0,-2},{1,-2}}       /* 0->3 */
};

static const Cell I_KICKS[8][5] = {
	{{0,0},{-2,0},{1,0},{-2,-1},{1,2}},
	{{0,0},{2,0},{-1,0},{2,1},{-1,-2}},
	{{0,0},{-1,0},{2,0},{-1,2},{2,-1}},
	{{0,0},{1,0},{-2,0},{1,-2},{-2,1}},
	{{0,0},{2,0},{-1,0},{2,1},{-1,-2}},
	{{0,0},{-2,0},{1,0},{-2,-1},{1,2}},
	{{0,0},{1,0},{-2,0},{1,-2},{-2,1}},
	{{0,0},{-1,0},{2,0},{-1,2},{2,-1}}
};

static int kick_table_index(int from, int to)
{
	static const struct { int from, to, idx; } pairs[8] = {
		{0,1,0},{1,0,1},{1,2,2},{2,1,3},{2,3,4},{3,2,5},{3,0,6},{0,3,7}
	};
	for (int i = 0; i < 8; i++) {
		if (pairs[i].from == from && pairs[i].to == to)
			return pairs[i].idx;
	}
	return 0;
}

int tetromino_get_kicks(PieceType type, int from_rotation, int to_rotation, Cell out[5])
{
	if (type == PIECE_O) {
		out[0].x = 0;
		out[0].y = 0;
		return 1;
	}

	int idx = kick_table_index(from_rotation & 3, to_rotation & 3);
	const Cell (*table)[5] = (type == PIECE_I) ? I_KICKS : JLSTZ_KICKS;

	for (int i = 0; i < 5; i++)
		out[i] = table[idx][i];

	return 5;
}
