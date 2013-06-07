<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2012, Phoronix Media
	Copyright (C) 2008 - 2012, Michael Larabel

	This program is free software; you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation; either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program. If not, see <http://www.gnu.org/licenses/>.
*/

class pts_render
{
	public static function render_graph(&$result_object, &$result_file = null, $save_as = false, $extra_attributes = null)
	{
		$graph = self::render_graph_process($result_object, $result_file, $save_as, $extra_attributes);
		$graph->renderGraph();

		return $graph->svg_dom->output($save_as);
	}
	public static function render_graph_inline_embed(&$object, &$result_file = null, $extra_attributes = null, $nested = true)
	{
		if($object instanceof pts_test_result)
		{
			$graph = self::render_graph_process($object, $result_file, false, $extra_attributes);
		}
		else if($object instanceof pts_Graph)
		{
			$graph = $object;
		}
		else
		{
			return false;
		}

		$graph->renderGraph();
		$output_format = 'SVG';
		$graph = $graph->svg_dom->output(null, $output_format);

		switch($output_format)
		{
			case 'PNG':
			case 'JPG':
				if($nested)
				{
					$graph = '<img src="data:image/png;base64,' . base64_encode($graph) . '" />';
				}
				else
				{
					header('Content-Type: image/' . strtolower($output_format));
				}
				break;
			default:
			case 'SVG':
				if($nested)
				{
					// strip out any DOCTYPE and other crud that would be redundant, so start at SVG tag
					$graph = substr($graph, strpos($graph, '<svg'));
				}
				else
				{
					header('Content-type: image/svg+xml');
				}
				break;
		}

		return $graph;
	}
	public static function multi_way_compact(&$result_file, &$result_object, $extra_attributes = null)
	{
		if($result_file == null)
		{
			return;
		}

		if(!isset($extra_attributes['compact_to_scalar']) && $result_object->test_profile->get_display_format() == 'LINE_GRAPH' && $result_file->get_system_count() > 10)
		{
			// If there's too many lines being plotted on line graph, likely to look messy, so convert to scalar automatically
			$extra_attributes['compact_to_scalar'] = true;
		}

		if($result_file->is_multi_way_comparison() || isset($extra_attributes['compact_to_scalar']) || $result_file->is_results_tracker())
		{
			if((isset($extra_attributes['compact_to_scalar']) || (false && $result_file->is_multi_way_comparison())) && in_array($result_object->test_profile->get_display_format(), array('LINE_GRAPH', 'FILLED_LINE_GRAPH')))
			{
				// Convert multi-way line graph into horizontal box plot
				if(false)
				{
					$result_object->test_profile->set_display_format('HORIZONTAL_BOX_PLOT');
				}
				else
				{
					// Turn a multi-way line graph into an averaged bar graph
					$buffer_items = $result_object->test_result_buffer->get_buffer_items();
					$result_object->test_result_buffer = new pts_test_result_buffer();

					foreach($buffer_items as $buffer_item)
					{
						$values = pts_strings::comma_explode($buffer_item->get_result_value());
						$avg_value = pts_math::set_precision(array_sum($values) / count($values), 2);
						$result_object->test_result_buffer->add_test_result($buffer_item->get_result_identifier(), $avg_value);
					}

					$result_object->test_profile->set_display_format('BAR_GRAPH');
				}
			}

			if($result_object->test_profile->get_display_format() != 'PIE_CHART')
			{
				$result_table = false;
				pts_render::compact_result_file_test_object($result_object, $result_table, $result_file, $extra_attributes);
			}
		}
		else if(in_array($result_object->test_profile->get_display_format(), array('LINE_GRAPH', 'FILLED_LINE_GRAPH')))
		{
				// Check to see for line graphs if every result is an array of the same result (i.e. a flat line for every result).
				// If all the results are just flat lines, you might as well convert it to a bar graph
				$buffer_items = $result_object->test_result_buffer->get_buffer_items();
				$all_values_are_flat = false;
				$flat_values = array();

				foreach($buffer_items as $i => $buffer_item)
				{
					$unique_in_buffer = array_unique(explode(',', $buffer_item->get_result_value()));
					$all_values_are_flat = count($unique_in_buffer) == 1;

					if($all_values_are_flat == false)
					{
						break;
					}
					$flat_values[$i] = array_pop($unique_in_buffer);
				}

				if($all_values_are_flat)
				{
					$result_object->test_result_buffer = new pts_test_result_buffer();
					foreach($buffer_items as $i => $buffer_item)
					{
						$result_object->test_result_buffer->add_test_result($buffer_item->get_result_identifier(), $flat_values[$i]);
					}

					$result_object->test_profile->set_display_format('BAR_GRAPH');
				}
		}
	}
	public static function render_graph_process(&$result_object, &$result_file = null, $save_as = false, $extra_attributes = null)
	{
		if(isset($extra_attributes['sort_result_buffer']))
		{
			$result_object->test_result_buffer->sort_buffer_items();
		}
		if(isset($extra_attributes['reverse_result_buffer']))
		{
			$result_object->test_result_buffer->buffer_values_reverse();
		}
		if(isset($extra_attributes['normalize_result_buffer']))
		{
			if(isset($extra_attributes['highlight_graph_values']) && is_array($extra_attributes['highlight_graph_values']) && count($extra_attributes['highlight_graph_values']) == 1)
			{
				$normalize_against = $extra_attributes['highlight_graph_values'][0];
			}
			else
			{
				$normalize_against = false;
			}

			$result_object->normalize_buffer_values($normalize_against);
		}

		if($result_file != null)
		{
			// Cache the redundant words on identifiers so it's not re-computed on every graph
			static $redundant_word_cache;

			if(!isset($redundant_word_cache[$result_file->get_title()]))
			{
				$redundant_word_cache[$result_file->get_title()] = pts_render::evaluate_redundant_identifier_words($result_file->get_system_identifiers());
			}

			if($redundant_word_cache[$result_file->get_title()])
			{
				$result_object->test_result_buffer->auto_shorten_buffer_identifiers($redundant_word_cache[$result_file->get_title()]);
			}
		}
		self::multi_way_compact($result_file, $result_object, $extra_attributes);

		$display_format = $result_object->test_profile->get_display_format();
		$bar_orientation = 'HORIZONTAL'; // default to horizontal bar graph

		switch($display_format)
		{
			case 'LINE_GRAPH':
				if(false && $result_object->test_result_buffer->get_count() > 5)
				{
					// If there's too many lines close to each other, it's likely to look cluttered so turn it into horizontal range bar / box chart graph
					$display_format = 'HORIZONTAL_BOX_PLOT';
					$graph = new pts_HorizontalBoxPlotGraph($result_object, $result_file);
				}
				else
				{
					$graph = new pts_LineGraph($result_object, $result_file);
				}
				break;
			case 'HORIZONTAL_BOX_PLOT':
				$graph = new pts_HorizontalBoxPlotGraph($result_object, $result_file);
				break;
			case 'BAR_ANALYZE_GRAPH':
			case 'BAR_GRAPH':
				if($bar_orientation == 'VERTICAL')
				{
					$graph = new pts_VerticalBarGraph($result_object, $result_file);
				}
				else
				{
					$graph = new pts_HorizontalBarGraph($result_object, $result_file);
				}
				break;
			case 'PASS_FAIL':
				$graph = new pts_PassFailGraph($result_object, $result_file);
				break;
			case 'MULTI_PASS_FAIL':
				$graph = new pts_MultiPassFailGraph($result_object, $result_file);
				break;
			case 'TEST_COUNT_PASS':
				$graph = new pts_TestCountPassGraph($result_object, $result_file);
				break;
			case 'PIE_CHART':
				$graph = new pts_PieChart($result_object, $result_file);
				break;
			case 'IMAGE_COMPARISON':
				$graph = new pts_ImageComparisonGraph($result_object, $result_file);
				break;
			case 'FILLED_LINE_GRAPH':
				$graph = new pts_FilledLineGraph($result_object, $result_file);
				break;
			case 'SCATTER_PLOT':
				$graph = new pts_ScatterPlot($result_object, $result_file);
				break;
			default:
				if(isset($extra_attributes['graph_render_type']))
				{
					$requested_graph_type = $extra_attributes['graph_render_type'];
				}
				else if(defined('GRAPH_RENDER_TYPE'))
				{
					$requested_graph_type = GRAPH_RENDER_TYPE;
				}
				else
				{
					$requested_graph_type = null;
				}

				switch($requested_graph_type)
				{
					case 'CANDLESTICK':
						$graph = new pts_CandleStickGraph($result_object, $result_file);
						break;
					case 'LINE_GRAPH':
						$graph = new pts_LineGraph($result_object, $result_file);
						break;
					case 'FILLED_LINE_GRAPH':
						$graph = new pts_FilledLineGraph($result_object, $result_file);
						break;
					default:
						if($bar_orientation == 'VERTICAL')
						{
							$graph = new pts_VerticalBarGraph($result_object, $result_file);
						}
						else
						{
							$graph = new pts_HorizontalBarGraph($result_object, $result_file);
						}
						break;
				}
				break;
		}

		if(isset($extra_attributes['regression_marker_threshold']))
		{
			$graph->markResultRegressions($extra_attributes['regression_marker_threshold']);
		}
		if(isset($extra_attributes['set_alternate_view']))
		{
			$graph->setAlternateView($extra_attributes['set_alternate_view']);
		}
		if(isset($extra_attributes['sort_result_buffer_values']))
		{
			$result_object->test_result_buffer->buffer_values_sort();

			if($result_object->test_profile->get_result_proportion() == 'HIB')
			{
				$result_object->test_result_buffer->buffer_values_reverse();
			}
		}
		if(isset($extra_attributes['highlight_graph_values']))
		{
			$graph->highlight_values($extra_attributes['highlight_graph_values']);
		}
		else if(PTS_IS_CLIENT && pts_client::read_env('GRAPH_HIGHLIGHT') != false)
		{
			$graph->highlight_values(pts_strings::comma_explode(pts_client::read_env('GRAPH_HIGHLIGHT')));
		}

		switch($display_format)
		{
			case 'LINE_GRAPH':
				if(isset($extra_attributes['no_overview_text']) && $graph instanceof pts_LineGraph)
				{
					$graph->plot_overview_text = false;
				}
			case 'FILLED_LINE_GRAPH':
			case 'BAR_ANALYZE_GRAPH':
			case 'SCATTER_PLOT':
				//$graph->hideGraphIdentifiers();
				foreach($result_object->test_result_buffer->get_buffer_items() as $buffer_item)
				{
					$graph->loadGraphValues(pts_strings::comma_explode($buffer_item->get_result_value()), $buffer_item->get_result_identifier());
					$graph->loadGraphRawValues(pts_strings::comma_explode($buffer_item->get_result_raw()));
				}

				$scale_special = $result_object->test_profile->get_result_scale_offset();
				if(!empty($scale_special) && count(($ss = pts_strings::comma_explode($scale_special))) > 0)
				{
					$graph->loadGraphIdentifiers($ss);
				}
				break;
			case 'HORIZONTAL_BOX_PLOT':
				// TODO: should be able to load pts_test_result_buffer_item objects more cleanly into pts_Graph
				$identifiers = array();
				$values = array();

				foreach($result_object->test_result_buffer->get_buffer_items() as $buffer_item)
				{
					array_push($identifiers, $buffer_item->get_result_identifier());
					array_push($values, pts_strings::comma_explode($buffer_item->get_result_value()));
				}

				$graph->loadGraphIdentifiers($identifiers);
				$graph->loadGraphValues($values);
				break;
			default:
				// TODO: should be able to load pts_test_result_buffer_item objects more cleanly into pts_Graph
				$identifiers = array();
				$values = array();
				$raw_values = array();

				foreach($result_object->test_result_buffer->get_buffer_items() as $buffer_item)
				{
					array_push($identifiers, $buffer_item->get_result_identifier());
					array_push($values, $buffer_item->get_result_value());
					array_push($raw_values, $buffer_item->get_result_raw());
				}

				$graph->loadGraphIdentifiers($identifiers);
				$graph->loadGraphValues($values);
				$graph->loadGraphRawValues($raw_values);
				break;
		}

		self::report_test_notes_to_graph($graph, $result_object);

		return $graph;
	}
	public static function report_system_notes_to_table(&$result_file, &$table)
	{
		$system_json = $result_file->get_system_json();
		$identifiers = $result_file->get_system_identifiers();
		$identifier_count = count($identifiers);
		$system_attributes = array();

		foreach($system_json as $i => $json)
		{
			if(isset($json['compiler-configuration']) && $json['compiler-configuration'] != null)
			{
				$system_attributes['Compiler'][$identifiers[$i]] = $json['compiler-configuration'];
			}
			if(isset($json['disk-scheduler']) && isset($json['disk-mount-options']))
			{
				$system_attributes['Disk'][$identifiers[$i]] = $json['disk-scheduler'] . ' / ' . $json['disk-mount-options'];
			}
			if(isset($json['cpu-scaling-governor']))
			{
				$system_attributes['Processor'][$identifiers[$i]] = 'Scaling Governor: ' . $json['cpu-scaling-governor'];
			}
			if(isset($json['graphics-2d-acceleration']))
			{
				$system_attributes['Graphics'][$identifiers[$i]] = '2D Acceleration: ' . $json['graphics-2d-acceleration'];
			}
			if(isset($json['graphics-compute-cores']))
			{
				$system_attributes['OpenCL'][$identifiers[$i]] = 'GPU Compute Cores: ' . $json['graphics-compute-cores'];
			}
		}

		if(isset($system_attributes['compiler']) && count($system_attributes['compiler']) == 1 && ($result_file->get_system_count() > 1 && ($intent = pts_result_file_analyzer::analyze_result_file_intent($result_file, $intent, true)) && isset($intent[0]) && is_array($intent[0]) && array_shift($intent[0]) == 'Compiler') == false)
		{
			// Only show compiler strings when it's meaningful (since they tend to be long strings)
			unset($system_attributes['compiler']);
		}

		foreach($system_attributes as $index_name => $attributes)
		{
			$unique_attribue_count = count(array_unique($attributes));

			$section = $identifier_count > 1 ? ucwords($index_name) : null;

			switch($unique_attribue_count)
			{
				case 0:
					break;
				case 1:
					if($identifier_count == count($attributes))
					{
						// So there is something for all of the test runs and it's all the same...
						$table->addTestNote(array_pop($attributes), null, $section);
					}
					else
					{
						// There is missing data for some test runs for this value so report the runs this is relevant to.
						$table->addTestNote(implode(', ', array_keys($attributes)) . ': ' . array_pop($attributes), null, $section);
					}
					break;
				default:
					foreach($attributes as $identifier => $configuration)
					{
						$table->addTestNote($identifier . ': ' . $configuration, null, $section);
					}
					break;
			}
		}
	}
	protected static function report_test_notes_to_graph(&$graph, &$result_object)
	{
		// do some magic here to report any test notes....
		$json = array();
		$unique_compiler_data = array();
		foreach($result_object->test_result_buffer->get_buffer_items() as $buffer_item)
		{
			$result_json = $buffer_item->get_result_json();

			if(!empty($result_json))
			{
				$json[$buffer_item->get_result_identifier()] = $result_json;
				if(isset($result_json['compiler-options']) && !empty($result_json['compiler-options']))
				{
					pts_arrays::unique_push($unique_compiler_data, $result_json['compiler-options']);
				}
			}
			// report against graph with $graph->addTestNote($note, $hover_title = null);
		}

		if(empty($json))
		{
			// no JSON data being reported to look at...
			return false;
		}

		$compiler_options_string = '(' . strtoupper($unique_compiler_data[0]['compiler-type']) . ') ' . $unique_compiler_data[0]['compiler'] . ' options: ';

		switch(count($unique_compiler_data))
		{
			case 0:
				break;
			case 1:
				if($unique_compiler_data[0]['compiler-options'] != null)
				{
					$graph->addTestNote($compiler_options_string . $unique_compiler_data[0]['compiler-options'], $unique_compiler_data[0]['compiler-options']);
				}
				break;
			default:
				$diff = call_user_func_array('array_diff_assoc', $unique_compiler_data);

				if(count($diff) == 1)
				{
					$key = array_keys($diff);
					$key = array_pop($key);
				}

				if(isset($diff[$key]))
				{
					$unique_compiler_data = array();
					foreach($json as $identifier => &$data)
					{
						if(isset($data['compiler-options'][$key]))
						{
							pts_arrays::unique_push($unique_compiler_data, explode(' ', $data['compiler-options'][$key]));
						}
					}

					if(($c0 = count($unique_compiler_data[0])) < ($c1 = count($unique_compiler_data[1])))
					{
						for($i = 0; $i < ($c1 - $c0); $i++)
						{
							// Make the length of the first array the same length
							array_push($unique_compiler_data[0], null);
						}
					}

					$diff = call_user_func_array('array_diff', $unique_compiler_data);

					if(count($diff) == 1)
					{
						$diff = array_search(array_pop($diff), $unique_compiler_data[0]);

						if($diff !== false)
						{
							if($key == 'compiler-options')
							{
								$intersect = call_user_func_array('array_intersect', $unique_compiler_data);
								$graph->addTestNote($compiler_options_string . implode(' ', $intersect));
							}

							foreach($json as $identifier => &$data)
							{
								if(isset($data['compiler-options'][$key]))
								{
									$options = explode(' ', $data['compiler-options'][$key]);

									if(isset($options[$diff]) && stripos($identifier, $options[$diff]) === false)
									{
										$graph->addGraphIdentifierNote($identifier, $options[$diff]);
									}
								}
							}
						}
					}
				}
				break;
		}
	}
	public static function evaluate_redundant_identifier_words($identifiers)
	{
		if(count($identifiers) < 6)
		{
			// Probably not worth shortening so few result identifiers
			return false;
		}

		// Breakup the an identifier into an array by spaces to be used for comparison
		$common_segments = explode(' ', pts_arrays::last_element($identifiers));

		if(!isset($common_segments[2]))
		{
			// If there aren't at least three words in identifier, probably can't be shortened well
			return false;
		}

		foreach($identifiers as &$identifier)
		{
			$this_identifier = explode(' ', $identifier);

			foreach($common_segments as $pos => $word)
			{
				if(!isset($this_identifier[$pos]) || $this_identifier[$pos] != $word || !isset($word[2]) || !ctype_alnum(substr($word, -1)))
				{
					// The word isn't the same OR the string is less than three characters (e.g. i7 or HD don't chop off from product names
					unset($common_segments[$pos]);
				}
			}

			if(count($common_segments) == 0)
			{
				// There isn't any common words to each identifier in result set
				return false;
			}
		}

		return $common_segments;
	}
	public static function generate_overview_object(&$overview_table, $overview_type)
	{
		switch($overview_type)
		{
			case 'GEOMETRIC_MEAN':
				$title = 'Geometric Mean';
				$math_call = array('pts_math', 'geometric_mean');
				break;
			case 'HARMONIC_MEAN':
				$title = 'Harmonic Mean';
				$math_call = array('pts_math', 'harmonic_mean');
				break;
			case 'AGGREGATE_SUM':
				$title = 'Aggregate Sum';
				$math_call = 'array_sum';
				break;
			default:
				return false;

		}
		$result_buffer = new pts_test_result_buffer();

		if($overview_table instanceof pts_result_file)
		{
			list($days_keys1, $days_keys, $shred) = pts_ResultFileTable::result_file_to_result_table($overview_table);

			foreach($shred as $system_key => &$system)
			{
				$to_show = array();

				foreach($system as &$days)
				{
					$days = $days->get_value();
				}

				array_push($to_show, pts_math::set_precision(call_user_func($math_call, $system), 2));
				$result_buffer->add_test_result($system_key, implode(',', $to_show), null);
			}
		}
		else
		{
			$days_keys = null;
			foreach($overview_table as $system_key => &$system)
			{
				if($days_keys == null)
				{
					// TODO: Rather messy and inappropriate way of getting the days keys
					$days_keys = array_keys($system);
					break;
				}
			}

			foreach($overview_table as $system_key => &$system)
			{
				$to_show = array();

				foreach($system as &$days)
				{
					array_push($to_show, call_user_func($math_call, $days));
				}

				$result_buffer->add_test_result($system_key, implode(',', $to_show), null);
			}
		}

		$test_profile = new pts_test_profile(null);
		$test_profile->set_test_title($title);
		$test_profile->set_result_scale($title);
		$test_profile->set_display_format('BAR_GRAPH');

		$test_result = new pts_test_result($test_profile);
		$test_result->set_used_arguments_description('Analytical Overview');
		$test_result->set_test_result_buffer($result_buffer);

		return $test_result;
	}
	public static function compact_result_file_test_object(&$mto, &$result_table = false, &$result_file, $extra_attributes = null)
	{
		$identifiers_inverted = $result_file && $result_file->is_multi_way_inverted();
		// TODO: this may need to be cleaned up, its logic is rather messy
		$condense_multi_way = isset($extra_attributes['condense_multi_way']);
		if(count($mto->test_profile->get_result_scale_offset()) > 0)
		{
			// It's already doing something
			return;
		}

		$scale_special = array();
		$days = array();
		$systems = array();
		$prev_date = null;
		$is_tracking = true;
		$sha1_short_count = 0;
		$buffer_count = $mto->test_result_buffer->get_count();

		if($identifiers_inverted)
		{
			$system_index = 0;
			$date_index = 1;
		}
		else
		{
			$system_index = 1;
			$date_index = 0;
		}

		foreach($mto->test_result_buffer->get_buffer_items() as $buffer_item)
		{
			$identifier = array_map('trim', explode(':', $buffer_item->get_result_identifier()));

			switch(count($identifier))
			{
				case 2:
					$system = $identifier[$system_index];
					$date = $identifier[$date_index];
					break;
				case 1:
					$system = 0;
					$date = $identifier[0];
					break;
				default:
					return;
					break;
			}

			if(!isset($systems[$system]))
			{
				$systems[$system] = 0;
			}
			if(!isset($days[$date]))
			{
				$days[$date] = null;
			}

			if($is_tracking)
			{
				// First do a dirty SHA1 hash check
				if(strlen($date) != 40 || strpos($date, ' ') !== false)
				{
					if(($x = strpos($date, ' + ')) !== false)
					{
						$date = substr($date, 0, $x);
					}

					// Check to see if only numeric changes are being made
					$sha1_short_hash_ending = isset($date[7]) && ctype_alnum(substr($date, -8));
					$date = str_replace('s', null, pts_strings::remove_from_string($date, pts_strings::CHAR_NUMERIC | pts_strings::CHAR_DASH | pts_strings::CHAR_DECIMAL));

					if($sha1_short_hash_ending)
					{
						$sha1_short_count++;
					}

					if($prev_date != null && $date != $prev_date && $sha1_short_hash_ending == false && $sha1_short_count < 3)
					{
						$is_tracking = false;
					}

					$prev_date = $date;
				}
			}
		}

		if($is_tracking)
		{
			$prev_date_r = explode(' ', $prev_date);

			if(count($prev_date_r) == 2 && ctype_alpha($prev_date_r[0]))
			{
				// This check should make it so when like testing every Ubuntu releases (Ubuntu 11.04, Ubuntu 11.10, etc) it's not in a line graph
				$is_tracking = false;
			}
		}
		else if($is_tracking == false && $sha1_short_count > 5)
		{
			// It's probably actually tracking..... based upon Stefan's Wine 1.4 example on 15 March 2012
			$is_tracking = true;
		}

		foreach(array_keys($days) as $day_key)
		{
			$days[$day_key] = $systems;
		}

		$raw_days = $days;
		$json_days = $days;

		foreach($mto->test_result_buffer->get_buffer_items() as $buffer_item)
		{
			$identifier = array_map('trim', explode(':', $buffer_item->get_result_identifier()));

			switch(count($identifier))
			{
				case 2:
					$system = $identifier[$system_index];
					$date = $identifier[$date_index];
					break;
				case 1:
					$system = 0;
					$date = $identifier[0];
					break;
				default:
					return;
					break;
			}

			$days[$date][$system] = $buffer_item->get_result_value();
			$raw_days[$date][$system] = $buffer_item->get_result_raw();
			$json_days[$date][$system] = $buffer_item->get_result_json();

			if(!is_numeric($days[$date][$system]))
			{
				return;
			}
		}

		$mto->test_result_buffer = new pts_test_result_buffer();
		$day_keys = array_keys($days);

		if($condense_multi_way)
		{
			$mto->set_used_arguments_description($mto->get_arguments_description() . ' | Composite Of: ' . implode(' - ', array_keys($days)));
			foreach(array_keys($systems) as $system_key)
			{
				$sum = 0;
				$count = 0;

				foreach($day_keys as $day_key)
				{
					$sum += $days[$day_key][$system_key];
					$count++;
				}

				$mto->test_result_buffer->add_test_result($system_key, ($sum / $count));
			}
		}
		else
		{
			$mto->test_profile->set_result_scale($mto->test_profile->get_result_scale() . ' | ' . implode(',', array_keys($days)));

			if($is_tracking && $buffer_count < 16 && $result_file && pts_result_file_analyzer::analyze_result_file_intent($result_file) != false)
			{
				// It can't be a tracker if the result file is comparing hardware/software, etc
				$is_tracking = false;
			}

			switch($mto->test_profile->get_display_format())
			{
				//case 'HORIZONTAL_BOX_PLOT':
				//	$mto->test_profile->set_display_format('HORIZONTAL_BOX_PLOT_MULTI');
				//	break;
				case 'SCATTER_PLOT';
					break;
				default:
					$line_graph_type = isset($extra_attributes['filled_line_graph']) ? 'FILLED_LINE_GRAPH' : 'LINE_GRAPH';
					$mto->test_profile->set_display_format((count($days) < 5 || ($is_tracking == false && !isset($extra_attributes['force_line_graph_compact'])) ? 'BAR_ANALYZE_GRAPH' : $line_graph_type));
					break;
			}

			foreach(array_keys($systems) as $system_key)
			{
				$results = array();
				$raw_results = array();
				$json_results = array();

				foreach($day_keys as $day_key)
				{
					array_push($results, $days[$day_key][$system_key]);
					array_push($raw_results, $raw_days[$day_key][$system_key]);
					pts_arrays::unique_push($json_results, $json_days[$day_key][$system_key]);
				}

				// TODO XXX: Make JSON data work for multi-way comparisons!

				if(count($json_results) == 1)
				{
					$json = array_shift($json_results);
				}
				else
				{
					$json = null;
				}

				$mto->test_result_buffer->add_test_result($system_key, implode(',', $results), implode(',', $raw_results), $json);
			}
		}

		if($result_table !== false)
		{
			foreach(array_keys($systems) as $system_key)
			{
				foreach($day_keys as $day_key)
				{
					if(!isset($result_table[$system_key][$day_key]))
					{
						$result_table[$system_key][$day_key] = array();
					}

					array_push($result_table[$system_key][$day_key], $days[$day_key][$system_key], $raw_days[$day_key][$system_key]);
				}
			}
		}
	}
	public static function multi_way_identifier_check($identifiers, &$system_hardware = null, &$result_file = null)
	{
		/*
			Samples To Use For Testing:
			1109026-LI-AMDRADEON57
		*/

		$systems = array();
		$targets = array();
		$is_multi_way = true;
		$is_multi_way_inverted = false;
		$is_ordered = true;
		$prev_system = null;

		foreach($identifiers as $identifier)
		{
			$identifier_r = explode(':', $identifier);

			if(count($identifier_r) != 2 || (isset($identifier[14]) && $identifier[4] == '-' && $identifier[13] == ':'))
			{
				// the later check will fix 0000-00-00 00:00 as breaking into date
				return false;
			}

			if(false && $is_ordered && $prev_system != null && $prev_system != $identifier_r[0] && isset($systems[$identifier_r[0]]))
			{
				// The results aren't ordered
				$is_ordered = false;

				if($result_file == null)
				{
					return false;
				}
			}

			$prev_system = $identifier_r[0];
			$systems[$identifier_r[0]] = !isset($systems[$identifier_r[0]]) ? 1 : $systems[$identifier_r[0]] + 1;
			$targets[$identifier_r[1]] = !isset($targets[$identifier_r[1]]) ? 1 : $targets[$identifier_r[1]] + 1;	
		}

		if(false && $is_ordered == false && $is_multi_way)
		{
			// TODO: get the reordering code to work
			if($result_file instanceof pts_result_file)
			{
				// Reorder the result file
				$to_order = array();
				sort($identifiers);
				foreach($identifiers as $identifier)
				{
					array_push($to_order, new pts_result_merge_select($result_file, $identifier));
				}

				$ordered_xml = pts_merge::merge_test_results_array($to_order);
				$result_file = new pts_result_file($ordered_xml);
				$is_multi_way = true;
			}
			else
			{
				$is_multi_way = false;
			}
		}

		$is_multi_way_inverted = $is_multi_way && count($targets) > count($systems);

		/*
		if($is_multi_way)
		{
			if(count($systems) < 3 && count($systems) != count($targets))
			{
				$is_multi_way = false;
			}
		}
		*/

		// TODO XXX: for now temporarily disable inverted multi-way check to decide how to rework it appropriately
		/*
		if($is_multi_way)
		{
			$targets_count = count($targets);
			$systems_count = count($systems);

			if($targets_count > $systems_count)
			{
				$is_multi_way_inverted = true;
			}
			else if(is_array($system_hardware))
			{
				$hardware = array_unique($system_hardware);
				//$software = array_unique($system_software);

				if($targets_count != $systems_count && count($hardware) == $systems_count)
				{
					$is_multi_way_inverted = true;
				}
				else if(count($hardware) == ($targets_count * $systems_count))
				{
					$is_multi_way_inverted = true;
				}
			}
		}
		*/

		// TODO: figure out what else is needed to reasonably determine if the result file is a multi-way comparison

		return $is_multi_way ? array($is_multi_way, $is_multi_way_inverted) : false;
	}
	public static function renderer_compatibility_check($user_agent)
	{
		$user_agent .= ' ';
		$selected_renderer = 'SVG';

		// Yahoo Slurp, msnbot, and googlebot should always be served SVG so no problems there

		if(($p = strpos($user_agent, 'Gecko/')) !== false)
		{
			// Mozilla Gecko-based browser (Firefox, etc)
			$gecko_date = substr($user_agent, ($p + 6));
			$gecko_date = substr($gecko_date, 0, 6);

			// Around Firefox 3.0 era is best
			// Firefox 2.0 mostly works except text might not show...
			if($gecko_date < 200702)
			{
				$selected_renderer = 'PNG';
			}
		}
		else if(($p = strpos($user_agent, 'AppleWebKit/')) !== false)
		{
			// Safari, Google Chrome, Google Chromium, etc
			$webkit_ver = substr($user_agent, ($p + 12));
			$webkit_ver = substr($webkit_ver, 0, strpos($webkit_ver, ' '));

			// Webkit 532.2 534.6 (WebOS 3.0.2) on WebOS is buggy for SVG
			// iPhone OS is using 533 right now
			if($webkit_ver < 533 || strpos($user_agent, 'hpwOS') !== false)
			{
				$selected_renderer = 'PNG';
			}

			if(($p = strpos($user_agent, 'Android ')) !== false)
			{
				$android_ver = substr($user_agent, ($p + 8), 3);

				// Android browser doesn't support SVG.
				// Google bug report 1376 for Android - http://code.google.com/p/android/issues/detail?id=1376
				// Looks like it might work though in 3.0 Honeycomb
				if($android_ver < 3.0)
				{
					$selected_renderer = 'PNG';
				}
			}
		}
		else if(($p = strpos($user_agent, 'Opera/')) !== false)
		{
			// Opera
			$ver = substr($user_agent, ($p + 6));
			$ver = substr($ver, 0, strpos($ver, ' '));

			// 9.27, 9.64 displays most everything okay
			if($ver < 9.27)
			{
				$selected_renderer = 'PNG';
			}

			// text-alignment is still fucked as of 11.50/12.0
			// With PTS4 and the bilde_svg_dom calls not using dominant-baseline, Opera support seems to be fine
			// $selected_renderer = 'PNG';
		}
		else if(($p = strpos($user_agent, 'Epiphany/')) !== false)
		{
			// Older versions of Epiphany. Newer versions should report their Gecko or WebKit appropriately
			$ver = substr($user_agent, ($p + 9));
			$ver = substr($ver, 0, 4);

			if($ver < 2.22)
			{
				$selected_renderer = 'PNG';
			}
		}
		else if(($p = strpos($user_agent, 'KHTML/')) !== false)
		{
			// KDE Konqueror as of 4.7 is still broken for SVG
			$selected_renderer = 'PNG';
		}
		else if(($p = strpos($user_agent, 'MSIE ')) !== false)
		{
			$ver = substr($user_agent, ($p + 5), 1);

			// Microsoft Internet Explorer 9.0 finally seems to do SVG right
			if($ver < 10 && $ver != 1)
			{
				$selected_renderer = 'PNG';
			}
		}
		else if(strpos($user_agent, 'facebook') !== false)
		{
			// Facebook uses this string for its Like/Share crawler, so serve it a PNG so it can use it as an image
			$selected_renderer = 'PNG';
		}

		return $selected_renderer;
	}
}

?>
