$.widget( "stonehearth.stonehearthMap", $.stonehearth.stonehearthMap, {

	typeHeights: {
		water:     0,
		sky:     0.5,
		plains:    1,
		foothills: 2,
		mountains: 3,
	},

	_drawCell: function(context, cellX, cellY, cell) {
		var self = this;
		var cellSize = self.options.cellSize;
		var x = cellX * cellSize;
		var y = cellY * cellSize;

		// draw elevation
		var terrain_code = cell.terrain_code;
		var color = self.options.mapInfo.color_map[terrain_code];
		var is_sky = self.options.mapGrid[cellY][cellX].is_sky;
		if (is_sky){
			var first_letter = 'EF';
			var second_letter = '0123456789ABCDEF';
			color = ''+first_letter[Math.floor(Math.random()*2)]+second_letter[Math.floor(Math.random()*16)];
			color = '#'+color+color+color;
			terrain_code = "sky"
		}

		context.fillStyle = color ? color : '#000000';
		context.fillRect(
			x, y,
			cellSize, cellSize
			);

		//var cellHeight = self._heightAt(cellX, cellY)
		context.lineWidth = 0.4;

		// draw edges for elevation changes
		if(self._isHigher(cellX, cellY - 1, terrain_code)) {
			// north, line above me
			self._drawLine(
				context,
				x, y,
				x + cellSize, y
				);

			//xxx, shading above me
			context.globalAlpha = 0.3;
			context.fillStyle = '#000000';
			context.fillRect(
				x, y,
				cellSize, cellSize * -0.4
				);
			if (is_sky){
				context.fillRect(
					x, y,
					cellSize, cellSize * 0.5
					);
			}
			context.globalAlpha = 1.0;
		}
		if(self._isHigher(cellX, cellY + 1,terrain_code)) {
			// south, line below me
			self._drawLine(
				context,
				x, y + cellSize,
				x + cellSize, y + cellSize
				);
		}
		if(self._isHigher(cellX - 1, cellY,terrain_code)) {
			// east, line on my left
			self._drawLine(
				context,
				x, y,
				x, y + cellSize
				);
		}
		if(self._isHigher(cellX + 1, cellY,terrain_code)) {
			// west, line on my right
			self._drawLine(
				context,
				x + cellSize, y,
				x + cellSize, y + cellSize
				);
		}

		// overlay forest
		var forest_density = self._forestAt(cellX, cellY)

		if (forest_density > 0 && terrain_code!="sky") {
			var margin = self.forestMargin[forest_density];
			context.fillStyle = self.options.mapInfo.color_map.trees || '#263C2C';
			//context.fillStyle = '#223025';   // darker color
			context.globalAlpha = 0.6;

			context.fillRect(
				x + margin, y + margin,
				cellSize - margin*2, cellSize - margin*2
				);
			context.globalAlpha = 1.0;
		}
	},

	_isHigher: function(x, y, terrain_code){
		var self = this;
		if (!self._inBounds(x, y)) {
			return false;
		}
		var terrain_code_xy = self.options.mapGrid[y][x].terrain_code;
		if (self.options.mapGrid[y][x].is_sky) {
			return false;
		}
		if (terrain_code=="sky") {
			return !self.options.mapGrid[y][x].is_sky;
		}
		var type_and_step = terrain_code.split("_");
		var type_and_step_xy = terrain_code_xy.split("_");
		var height = self.typeHeights[type_and_step[0]];
		var height_xy = self.typeHeights[type_and_step_xy[0]];
		if (height_xy > height) {
			return true;
		}
		var step = parseInt(type_and_step[1]);
		var step_xy = parseInt(type_and_step_xy[1]);
		if (height_xy == height && step_xy > step) {
			return true;
		}
		return false;
	}
});