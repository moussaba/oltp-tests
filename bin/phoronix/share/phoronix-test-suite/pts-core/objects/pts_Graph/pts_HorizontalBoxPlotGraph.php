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

class pts_HorizontalBoxPlotGraph extends pts_HorizontalBarGraph
{
	protected function render_graph_bars()
	{
		$bar_count = count($this->graph_data);
		$separator_height = ($a = (6 - (floor($bar_count / 2) * 2))) > 0 ? $a : 0;
		$multi_way = $this->is_multi_way_comparison && count($this->graph_data) > 1;
		$bar_height = floor(($this->i['identifier_height'] - ($multi_way ? 4 : 0) - $separator_height - ($bar_count * $separator_height)) / $bar_count);

		for($i_o = 0; $i_o < $bar_count; $i_o++)
		{
			$paint_color = $this->get_paint_color((isset($this->graph_data_title[$i_o]) ? $this->graph_data_title[$i_o] : null));

			foreach(array_keys($this->graph_data[$i_o]) as $i)
			{
				$min_value = round(min($this->graph_data[$i_o][$i]), 2);
				$avg_value = round(array_sum($this->graph_data[$i_o][$i]) / count($this->graph_data[$i_o][$i]), 2);
				$max_value = round(max($this->graph_data[$i_o][$i]), 2);

				$px_bound_top = $this->i['top_start'] + ($multi_way ? 5 : 0) + ($this->i['identifier_height'] * $i) + ($bar_height * $i_o) + ($separator_height * ($i_o + 1));
				$px_bound_bottom = $px_bound_top + $bar_height;
				$middle_of_bar = $px_bound_top + ($bar_height / 2);

				$value = 'Min: ' . $min_value . ' / Avg: ' . $avg_value . ' / Max: ' . $max_value;
				$title_tooltip = $this->graph_identifiers[$i] . ': ' . $value;

				$value_end_left = max($this->i['left_start'] + round(($min_value / $this->i['graph_max_value']) * ($this->i['graph_left_end'] - $this->i['left_start'])), 1);
				$value_end_right = $this->i['left_start'] + round(($max_value / $this->i['graph_max_value']) * ($this->i['graph_left_end'] - $this->i['left_start']));
				$box_color = in_array($this->graph_identifiers[$i], $this->value_highlights) ? self::$c['color']['highlight'] : $paint_color;

				$this->svg_dom->draw_svg_line($value_end_left, $middle_of_bar, $value_end_right, $middle_of_bar, $box_color, 2, array('xlink:title' => $title_tooltip));
				$this->svg_dom->draw_svg_line($value_end_left, $px_bound_top, $value_end_left, $px_bound_bottom, self::$c['color']['notches'], 2, array('xlink:title' => $title_tooltip));
				$this->svg_dom->draw_svg_line($value_end_right, $px_bound_top, $value_end_right, $px_bound_bottom, self::$c['color']['notches'], 2, array('xlink:title' => $title_tooltip));

				$box_left = $this->i['left_start'] + round((pts_math::find_percentile($this->graph_data[$i_o][$i], 0.25) / $this->i['graph_max_value']) * ($this->i['graph_left_end'] - $this->i['left_start']));
				$box_middle = $this->i['left_start'] + round((pts_math::find_percentile($this->graph_data[$i_o][$i], 0.5) / $this->i['graph_max_value']) * ($this->i['graph_left_end'] - $this->i['left_start']));
				$box_right = $this->i['left_start'] + round((pts_math::find_percentile($this->graph_data[$i_o][$i], 0.75) / $this->i['graph_max_value']) * ($this->i['graph_left_end'] - $this->i['left_start']));

				$this->svg_dom->add_element('rect', array('x' => $box_left, 'y' => $px_bound_top, 'width' => ($box_right - $box_left), 'height' => $bar_height, 'fill' => $box_color, 'stroke' => self::$c['color']['body_light'], 'stroke-width' => 1, 'xlink:title' => $title_tooltip));
				$this->svg_dom->draw_svg_line($box_middle, $px_bound_top, $box_middle, $px_bound_bottom, self::$c['color']['notches'], 2, array('xlink:title' => $title_tooltip));
			}
		}

		// write a new line along the bottom since the draw_rectangle_with_border above had written on top of it
		$this->svg_dom->draw_svg_line($this->i['left_start'], $this->i['graph_top_end'], $this->i['graph_left_end'], $this->i['graph_top_end'], self::$c['color']['notches'], 1);
	}
	protected function maximum_graph_value()
	{
		$real_maximum = 0;

		foreach($this->graph_data as &$data_r)
		{
			$real_maximum = max($real_maximum, max(max($data_r)));
		}

		$maximum = (floor(round($real_maximum * 1.285) / $this->i['mark_count']) + 1) * $this->i['mark_count'];
		$maximum = round(ceil($maximum / $this->i['mark_count']), (0 - strlen($maximum) + 2)) * $this->i['mark_count'];

		return $maximum;
	}
}

?>
