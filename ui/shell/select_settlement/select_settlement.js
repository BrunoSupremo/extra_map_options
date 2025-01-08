App.StonehearthSelectSettlementView = App.View.extend({
	templateName: 'stonehearthSelectSettlement',
	i18nNamespace: 'stonehearth',

	classNames: ['flex', 'fullScreen', 'selectSettlementBackground'],

	options: {},
	analytics: {},
	map_options_table: {},
	map_options_table_default: {},

	init: function() {
		this._super();
		var self = this;
	},

	didInsertElement: function() {
		this._super();
		var self = this;

		var biome_uri = self.get('options.biome_src');
		var kingdom_uri = self.get('options.starting_kingdom');
		self.$('#selectSettlement').addClass(biome_uri);
		self.$('#selectSettlement').addClass(kingdom_uri);
		self.$('.bullet').addClass(biome_uri);

		$.get('/extra_map_options/data/extra_map_options.json')
		.done(function (result) {
			//grabs defaults and biome specific values
			let current = result.biome_options["default"];
			let biome = result.biome_options[biome_uri];
			//overwrite defaults with biome specifics
			$.extend( true, current, biome );
			self.map_options_table = JSON.parse(JSON.stringify(current));
			self.map_options_table_default = JSON.parse(JSON.stringify(current));

			self.hide_ui_parts();
			self.map_options_to_ui();

			self._newGame(self._generate_seed(), function (e) {
				radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:paper_menu'} );
				self.$('#map').stonehearthMap({
					mapGrid: e.map,
					mapInfo: e.map_info,

					click: function(cellX, cellY) {
						self._chooseLocation(cellX, cellY);
					},

					hover: function(cellX, cellY) {
						var map = $('#map').stonehearthMap('getMap');
						var cell = map[cellY] && map[cellY][cellX];
						if (cell) {
							self._updateScroll(cell);
						}
					}
				});
			});
		});

		$('body').on( 'click', '#selectSettlementButton', function() {
			self._selectSettlement(self._selectedX, self._selectedY);
		});

		$('body').on( 'click', '#clearSelectionButton', function() {
			self._clearSelection();
		});

		self.$("#regenerateButton").click(function() {
			if (self.$("#regenerateButton").hasClass('disabled')) {
				return;
			}

			radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:reroll'} );
			self._clearSelection();
			self.$('#map').hide();
			self.$('#map').stonehearthMap('suspend');

			self._newGame(self._generate_seed(), function(e) {
				radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:paper_menu'} );
				self.$('#map').show();
				self.$('#map').stonehearthMap('setMap', e.map, e.map_info);
				self.$('#map').stonehearthMap('resume');
			});
		});

		new StonehearthInputHelper(this.$('#worldSeedInput'), function (value) {
			var worldSeed = self.get('world_seed');
			if (self.$("#regenerateButton").hasClass('disabled')) {
				self.$('#worldSeedInput').val(worldSeed);
				return;
			}
			var seed = parseInt(value);
			if (isNaN(seed)) {
				self.$('#worldSeedInput').val(worldSeed);
				return;
			}

			if (seed != worldSeed) {
				self.$('#map').hide();
				self.$('#map').stonehearthMap('suspend');
				self._newGame(seed ,function(e) {
					self.$('#map').show();
					radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:paper_menu'} );
					self.$('#map').stonehearthMap('setMap', e.map, e.map_info);
					self.$('#map').stonehearthMap('resume');
				});
			}
		});

		$(document).on('keydown', this._clearSelectionKeyHandler);

		self._animateLoading();

		self.$('#map_options').draggable();
	},

	_loadSeasons: function () {
		var self = this;
		var biome_uri = self.get('options.biome_src');
		if (biome_uri) {
			self.trace = radiant.trace(biome_uri)
			.progress(function (biome) {
				self.set('seasons', radiant.map_to_array(biome.seasons, function(k, b) { b.id = k; }));

				Ember.run.scheduleOnce('afterRender', this, function () {
					self.$('[data-season-id]').each(function () {
						var $el = $(this);
						var id = $el.attr('data-season-id');
						var description = biome.seasons[id].description;
						if (description) {
							$el.tooltipster({ content: i18n.t(description), position: 'bottom' });
						}
					});
					if (biome.default_starting_season) {
						self.$('[data-season-id="' + biome.default_starting_season + '"] input').attr('checked', true);
					} else {
						self.$('[data-season-id] input').first().attr('checked', true);
					}
				});
			});
		}
	}.observes('options.biome_src'),

	seasonRows: function () {
		var self = this;
		var i = 0;
		var result = [];
		radiant.each(self.get('seasons'), function (_, season) {
			var row = Math.floor(i / 2);
			if (!result[row]) result[row] = [];
			result[row].push(season);
			++i;
		});
		return result;
	}.property('seasons'),

	destroy: function() {
		$(document).off('keydown', this._clearSelectionKeyHandler);
		if (this._loadingAnimationInterval) {
			clearInterval(this._loadingAnimationInterval);
			this._loadingAnimationInterval = null;
		}
		this._super();
	},

	_animateLoading: function() {
		var self = this;
		var loadingElement = self.$('#loadingPeriods');

		var periodsCount = 0;
		var currentPeriods = '';
		self._loadingAnimationInterval = setInterval(function() {
			loadingElement.html(currentPeriods);

			periodsCount++;
			if (periodsCount >= 4) {
				periodsCount = 0;
				currentPeriods = '';
			} else {
				currentPeriods = currentPeriods + '.';
			}

		}, 250);

	},

	_chooseLocation: function(cellX, cellY) {
		var self = this;

		self._selectedX = cellX;
		self._selectedY = cellY;

		self.$('#map').stonehearthMap('suspend');

		self.$('#selectSettlementPin').show();
		self.$('#selectSettlementPin').position({
			my: 'left+' + 12 * cellX + ' top+' + 12 * cellY,
			at: 'left top',
			of: self.$('#map'),
		});

		var tipContent = '<div id="selectSettlementTooltip">';
		tipContent += '<button id="selectSettlementButton" class="flat">' + i18n.t('stonehearth:ui.shell.select_settlement.settle_at_this_location') + '</button><br>';
		tipContent += '<button id="clearSelectionButton" class="flat">' + i18n.t('stonehearth:ui.shell.select_settlement.clear_selection') + '</button>';
		tipContent += '</div>';

		self.$('#selectSettlementPin').tooltipster({
			autoClose: false,
			interactive: true,
			content:  $(tipContent)
		});

		self.$('#selectSettlementPin').tooltipster('show');
	},

	_newGame: function(seed, fn) {
		var self = this;
		self.set('world_seed', seed);

		self.$("#regenerateButton").addClass('disabled');
		self.$('#worldSeedInput').attr('disabled', 'disabled');
		self.$('#open_map_options').attr('disabled', 'disabled');

		radiant.call_obj('stonehearth.game_creation', 'new_game_command', 12, 8, seed, self.options, self.analytics, self.map_options_table)
		.done(function(e) {
			self._map_info = e.map_info;
			fn(e);
			self.$('#map').stonehearthMap('option','settlementRadius', self.map_options_table.world_size*9+1);
		})
		.fail(function(e) {
			console.error('new_game failed:', e);
		})
		.always(function() {
			self.$("#regenerateButton").removeClass('disabled');
			self.$('#worldSeedInput').removeAttr('disabled');
			self.$('#open_map_options').removeAttr('disabled');
		});
	},

	_generate_seed: function() {
		var MAX_INT32 = 2147483647;
		var seed = Math.floor(Math.random() * (MAX_INT32+1));
		return seed;
	},

	_updateScroll: function(cell) {
		var self = this;
		var terrainType = '';
		var vegetationDescription = '';
		var wildlifeDescription = '';

		if (cell != null) {
			self.$('#scroll').show();

			if (self._map_info && self._map_info.custom_name_map && self._map_info.custom_name_map[cell.terrain_code]) {
				terrainType = i18n.t(self._map_info.custom_name_map[cell.terrain_code]);
			} else {
				terrainType = i18n.t('stonehearth:ui.shell.select_settlement.terrain_codes.' + cell.terrain_code);
			}

			vegetationDescription = cell.vegetation_density;
			wildlifeDescription = cell.wildlife_density;
			// mineralDescription = cell.mineral_density;

			if (cell.terrain_code != this._prevTerrainCode) {
				// var portrait = 'url(/stonehearth/ui/shell/select_settlement/images/' + cell.terrain_code + '.png)';
				self.$('#terrainType').html(terrainType);
				this._prevTerrainCode = cell.terrain_code;
			}

			self._updateTileRatings(self.$('#vegetation'), cell.vegetation_density);
			self._updateTileRatings(self.$('#wildlife'), cell.wildlife_density);
			self._updateTileRatings(self.$('#minerals'), cell.mineral_density);
		} else {
			self.$('#scroll').hide();
		}
	},

	_updateTileRatings: function(el, rating) {
		el.find('.bullet')
		.removeClass('full');

		for(var i = 1; i < rating + 1; i++) {
			el.find('.' + i).addClass('full');
		}
	},

	_clearSelection: function() {
		var self = this;

		try {
			self.$('#selectSettlementPin').tooltipster('destroy');
			self.$('#selectSettlementPin').hide();
			radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:carpenter_menu:menu_closed'} );
		} catch(e) {
		}

		self.$('#map').stonehearthMap('clearCrosshairs');
		self._updateScroll(null);

		if (self.$('#map').stonehearthMap('suspended')) {
			self.$('#map').stonehearthMap('resume');
		}
	},

	_clearSelectionKeyHandler: function(e) {
		// var self = this;

		var escape_key_code = 27;

		if (e.keyCode == escape_key_code) {
			$('#clearSelectionButton').click();
		}
	},

	_selectSettlement: function(cellX, cellY) {
		var self = this;

		radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:embark'} );
		radiant.call_obj('stonehearth.game_creation', 'generate_start_location_command', cellX, cellY, self._map_info)
		.fail(function(e) {
			console.error('generate_start_location_command failed:', e);
		});

		var chosenSeason = self.$('[data-season-id] input:checked');
		if (chosenSeason && chosenSeason.length) {
			var transitionDays = parseInt(App.constants.seasons.TRANSITION_LENGTH) || 0;
			var seasonStartDay = parseInt(chosenSeason.attr('data-season-start-day'));
			radiant.call('stonehearth:set_start_day', seasonStartDay + transitionDays);
		}

		App.navigate('shell/loading');
		self.destroy();
	},

	hide_ui_parts: function() {
		var self = this;
		if(self.map_options_table.hide_from_ui.world_size){
			document.getElementById("world_size").style.display = "none";
		}
		if (self.map_options_table.hide_from_ui.lakes && self.map_options_table.hide_from_ui.dirt_holes){
			document.getElementById("enable").style.display = "none";
		}else{
			if (self.map_options_table.hide_from_ui.lakes){
				document.getElementById("lakeChoice").style.display = "none";
				document.querySelector("#lakeChoice + label").style.display = "none";
			}
			if (self.map_options_table.hide_from_ui.dirt_holes){
				document.getElementById("dirtHoleChoice").style.display = "none";
				document.querySelector("#dirtHoleChoice + label").style.display = "none";
			}
		}
		if(self.map_options_table.hide_from_ui.landmarks){
			document.getElementById("landmarks").style.display = "none";
		}
		if(self.map_options_table.hide_from_ui.rivers.quantity && self.map_options_table.hide_from_ui.rivers.plains && self.map_options_table.hide_from_ui.rivers.foothills && self.map_options_table.hide_from_ui.rivers.mountains && self.map_options_table.hide_from_ui.rivers.radius ){
			document.getElementById("rivers").style.display = "none";
		}else{
			if(self.map_options_table.hide_from_ui.rivers.quantity){
				document.getElementById("quantity").style.display = "none";
				document.getElementById("quantity_label").style.display = "none";
			}
			if(self.map_options_table.hide_from_ui.rivers.plains && self.map_options_table.hide_from_ui.rivers.foothills && self.map_options_table.hide_from_ui.rivers.mountains ){
				document.getElementById("locations").style.display = "none";
			}else{
				if(self.map_options_table.hide_from_ui.rivers.plains){
					document.getElementById("riverPlains").style.display = "none";
					document.querySelector("#riverPlains + label").style.display = "none";
				}
				if(self.map_options_table.hide_from_ui.rivers.foothills){
					document.getElementById("riverFoothills").style.display = "none";
					document.querySelector("#riverFoothills + label").style.display = "none";
				}
				if(self.map_options_table.hide_from_ui.rivers.mountains){
					document.getElementById("riverMountains").style.display = "none";
					document.querySelector("#riverMountains + label").style.display = "none";
				}
			}
			if(self.map_options_table.hide_from_ui.rivers.radius){
				document.getElementById("sizes").style.display = "none";
			}
		}
		if(self.map_options_table.hide_from_ui.modes.superflat && self.map_options_table.hide_from_ui.modes.waterworld && self.map_options_table.hide_from_ui.modes.canyons && self.map_options_table.hide_from_ui.modes.sky_lands ){
			document.getElementById("special_modes").style.display = "none";
		}else{
			if(self.map_options_table.hide_from_ui.modes.superflat){
				document.getElementById("superFlatChoice").style.display = "none";
				document.querySelector("#superFlatChoice + label").style.display = "none";
			}
			if(self.map_options_table.hide_from_ui.modes.waterworld){
				document.getElementById("waterWorldChoice").style.display = "none";
				document.querySelector("#waterWorldChoice + label").style.display = "none";
			}
			if(self.map_options_table.hide_from_ui.modes.canyons){
				document.getElementById("canyonsChoice").style.display = "none";
				document.querySelector("#canyonsChoice + label").style.display = "none";
			}
			if(self.map_options_table.hide_from_ui.modes.sky_lands){
				document.getElementById("skyLandsChoice").style.display = "none";
				document.querySelector("#skyLandsChoice + label").style.display = "none";
			}
		}
	},
	reset_map_options: function() {
		var self = this;
		let map_options_copy = JSON.parse(JSON.stringify(self.map_options_table));

		self.map_options_table = self.map_options_table_default;
		self.map_options_to_ui();

		self.map_options_table = JSON.parse(JSON.stringify(map_options_copy));
	},
	map_options_to_ui: function() {
		var self = this;
		if (self.map_options_table.world_size == 0) {
			document.getElementById("size0").checked = true;
		}
		if (self.map_options_table.world_size == 1) {
			document.getElementById("size1").checked = true;
		}
		if (self.map_options_table.world_size == 2) {
			document.getElementById("size2").checked = true;
		}
		if (self.map_options_table.world_size == 4) {
			document.getElementById("size4").checked = true;
		}
		if (self.map_options_table.landmarks == 0) {
			document.getElementById("amount0").checked = true;
		}
		if (self.map_options_table.landmarks == 1) {
			document.getElementById("amount1").checked = true;
		}
		if (self.map_options_table.landmarks == 2) {
			document.getElementById("amount2").checked = true;
		}
		document.getElementById("quantity").value = self.map_options_table.rivers.quantity;
		document.getElementById("riverPlains").checked = self.map_options_table.rivers.plains;
		document.getElementById("riverFoothills").checked = self.map_options_table.rivers.foothills;
		document.getElementById("riverMountains").checked = self.map_options_table.rivers.mountains;
		if (self.map_options_table.rivers.radius == 2) {
			document.getElementById("riverWide").checked = true;
		}else{
			document.getElementById("riverNarrow").checked = true;
		}
		document.getElementById("lakeChoice").checked = self.map_options_table.lakes;
		document.getElementById("dirtHoleChoice").checked = self.map_options_table.dirt_holes;
		document.getElementById("superFlatChoice").checked = self.map_options_table.modes.superflat;
		document.getElementById("waterWorldChoice").checked = self.map_options_table.modes.waterworld;
		document.getElementById("canyonsChoice").checked = self.map_options_table.modes.canyons;
		document.getElementById("skyLandsChoice").checked = self.map_options_table.modes.sky_lands;
	},
	ui_to_map_options: function() {
		var self = this;

		if (document.getElementById("size0").checked){
			self.map_options_table.world_size = 0;
		}
		if (document.getElementById("size1").checked){
			self.map_options_table.world_size = 1;
		}
		if (document.getElementById("size2").checked){
			self.map_options_table.world_size = 2;
		}
		if (document.getElementById("size4").checked){
			self.map_options_table.world_size = 4;
		}
		if (document.getElementById("amount0").checked){
			self.map_options_table.landmarks = 0;
		}
		if (document.getElementById("amount1").checked){
			self.map_options_table.landmarks = 1;
		}
		if (document.getElementById("amount2").checked){
			self.map_options_table.landmarks = 2;
		}
		self.map_options_table.rivers.quantity = parseInt(document.getElementById("quantity").value);
		self.map_options_table.rivers.plains = document.getElementById("riverPlains").checked;
		self.map_options_table.rivers.foothills = document.getElementById("riverFoothills").checked;
		self.map_options_table.rivers.mountains = document.getElementById("riverMountains").checked;
		if (document.getElementById("riverWide").checked) {
			self.map_options_table.rivers.radius = 2;
		}else{
			self.map_options_table.rivers.radius = 1;
		}
		self.map_options_table.lakes = document.getElementById("lakeChoice").checked;
		self.map_options_table.dirt_holes = document.getElementById("dirtHoleChoice").checked;
		self.map_options_table.modes.superflat = document.getElementById("superFlatChoice").checked;
		self.map_options_table.modes.waterworld = document.getElementById("waterWorldChoice").checked;
		self.map_options_table.modes.canyons = document.getElementById("canyonsChoice").checked;
		self.map_options_table.modes.sky_lands = document.getElementById("skyLandsChoice").checked;
	},

	actions: {
		quitToMainMenu: function() {
			App.stonehearthClient.quitToMainMenu('shellView');
		},
		open_map_options: function(){
			document.querySelector("#map_options").style.display = "block";
		},
		apply_map_options: function(){
			var self = this;
			document.querySelector("#map_options").style.display = "none";

			self.ui_to_map_options();

			self.$('#map').hide();
			self.$('#map').stonehearthMap('suspend');
			self._newGame(self.get('world_seed'), function(e) {
				self.$('#map').show();
				radiant.call('radiant:play_sound', {'track' : 'stonehearth:sounds:ui:start_menu:paper_menu'} );
				self.$('#map').stonehearthMap('setMap', e.map, e.map_info);
				self.$('#map').stonehearthMap('resume');
			});
		},
		default_map_options: function(){
			var self = this;
			self.reset_map_options();
		},
		cancel_map_options: function(){
			var self = this;
			document.querySelector("#map_options").style.display = "none";

			self.map_options_to_ui();
		}
	}
});