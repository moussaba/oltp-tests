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

class pts_network
{
	private static $disable_network_support = false;
	private static $network_proxy = false;

	public static function network_support_available()
	{
		return self::$disable_network_support == false;
	}
	public static function http_get_contents($url, $override_proxy = false, $override_proxy_port = false)
	{
		if(!pts_network::network_support_available())
		{
			return false;
		}

		$stream_context = pts_network::stream_context_create(null, $override_proxy, $override_proxy_port);
		$contents = pts_file_io::file_get_contents($url, 0, $stream_context);

		return $contents;
	}
	public static function http_upload_via_post($url, $to_post_data)
	{
		if(!pts_network::network_support_available())
		{
			return false;
		}

		$upload_data = http_build_query($to_post_data);
		$http_parameters = array('http' => array('method' => 'POST', 'content' => $upload_data));
		$stream_context = pts_network::stream_context_create($http_parameters);
		$opened_url = fopen($url, 'rb', false, $stream_context);
		$response = $opened_url ? stream_get_contents($opened_url) : false;

		return $response;
	}
	public static function download_file($download, $to)
	{
		if(!pts_network::network_support_available())
		{
			return false;
		}

		if(function_exists('curl_init'))
		{
			$return_state = pts_network::curl_download($download, $to);
		}
		else
		{
			$return_state = pts_network::stream_download($download, $to);
		}

		//echo '\nPHP CURL must either be installed or you must adjust your PHP settings file to support opening FTP/HTTP streams.\n';
		//return false;

		if($return_state == true)
		{
			pts_client::$display->test_install_progress_completed();
		}
	}
	public static function curl_download($download, $download_to)
	{
		if(!function_exists('curl_init'))
		{
			return false;
		}

		// with curl_multi_init we could do multiple downloads at once...
		$cr = curl_init();
		$fh = fopen($download_to, 'w');

		curl_setopt($cr, CURLOPT_FILE, $fh);
		curl_setopt($cr, CURLOPT_URL, $download);
		curl_setopt($cr, CURLOPT_HEADER, false);
		curl_setopt($cr, CURLOPT_FOLLOWLOCATION, true);
		curl_setopt($cr, CURLOPT_CONNECTTIMEOUT, (defined('NETWORK_TIMEOUT') ? NETWORK_TIMEOUT : 20));
		curl_setopt($cr, CURLOPT_CAPATH, PTS_CORE_STATIC_PATH . 'certificates/');
		curl_setopt($cr, CURLOPT_BUFFERSIZE, 64000);
		curl_setopt($cr, CURLOPT_USERAGENT, pts_codename(true));

		if(stripos($download, 'sourceforge') === false)
		{
			// Setting the referer causes problems for SourceForge downloads
			curl_setopt($cr, CURLOPT_REFERER, 'http://www.phoronix-test-suite.com/');
		}

		if(strpos($download, 'https://openbenchmarking.org/') !== false)
		{
			curl_setopt($cr, CURLOPT_SSL_VERIFYPEER, true);
			curl_setopt($cr, CURLOPT_SSL_VERIFYHOST, 2);
			curl_setopt($cr, CURLOPT_CAINFO, PTS_CORE_STATIC_PATH . 'certificates/openbenchmarking-server.pem');
		}
		else if(strpos($download, 'https://www.phoromatic.com/') !== false)
		{
			curl_setopt($cr, CURLOPT_SSL_VERIFYPEER, true);
			curl_setopt($cr, CURLOPT_SSL_VERIFYHOST, 2);
			curl_setopt($cr, CURLOPT_CAINFO, PTS_CORE_STATIC_PATH . 'certificates/phoromatic-com.pem');
		}

		if(PHP_VERSION_ID >= 50300)
		{
			// CURLOPT_PROGRESSFUNCTION only seems to work with PHP 5.3+
			curl_setopt($cr, CURLOPT_NOPROGRESS, false);
			curl_setopt($cr, CURLOPT_PROGRESSFUNCTION, array('pts_network', 'curl_status_callback'));
		}

		if(self::$network_proxy)
		{
			curl_setopt($cr, CURLOPT_PROXY, self::$network_proxy['proxy']);
		}

		curl_exec($cr);
		curl_close($cr);
		fclose($fh);

		return true;
	}
	public static function stream_download($download, $download_to, $stream_context_parameters = null, $callback_function = array('pts_network', 'stream_status_callback'))
	{
		$stream_context = pts_network::stream_context_create($stream_context_parameters);
		stream_context_set_params($stream_context, array('notification' => $callback_function));

		/*
		if(strpos($download, 'https://openbenchmarking.org/') !== false)
		{
			stream_context_set_option($stream_context, 'ssl', 'local_cert', PTS_CORE_STATIC_PATH . 'certificates/openbenchmarking-server.pem');
		}
		else if(strpos($download, 'https://www.phoromatic.com/') !== false)
		{
			stream_context_set_option($stream_context, 'ssl', 'local_cert', PTS_CORE_STATIC_PATH . 'certificates/phoromatic-com.pem');
		}
		*/

		$file_pointer = @fopen($download, 'r', false, $stream_context);

		if(is_resource($file_pointer) && file_put_contents($download_to, $file_pointer))
		{
			return true;
		}

		return false;
	}
	public static function stream_context_create($parameters = null, $proxy_address = false, $proxy_port = false)
	{
		if(!is_array($parameters))
		{
			$parameters = array();
		}

		if($proxy_address == false && $proxy_port == false && self::$network_proxy)
		{
			$proxy_address = self::$network_proxy['address'];
			$proxy_port = self::$network_proxy['port'];
		}

		if($proxy_address != false && $proxy_port != false && is_numeric($proxy_port))
		{
			$parameters['http']['proxy'] = 'tcp://' . $proxy_address . ':' . $proxy_port;
			$parameters['http']['request_fulluri'] = true;
		}

		$parameters['http']['timeout'] = defined('NETWORK_TIMEOUT') ? NETWORK_TIMEOUT : 20;
		$parameters['http']['user_agent'] = pts_codename(true);
		$parameters['http']['header'] = "Content-Type: application/x-www-form-urlencoded\r\n";

		$stream_context = stream_context_create($parameters);

		return $stream_context;
	}

	//
	// Callback Functions
	//

	public static function stream_status_callback($notification_code, $arg1, $message, $message_code, $downloaded, $download_size)
	{
		static $filesize = 0;
		static $last_float = -1;

		switch($notification_code)
		{
			case STREAM_NOTIFY_FILE_SIZE_IS:
				$filesize = $download_size;
				break;
			case STREAM_NOTIFY_PROGRESS:
				$downloaded_float = $filesize == 0 ? 0 : $downloaded / $filesize;

				if(abs($downloaded_float - $last_float) < 0.01)
				{
					return;
				}

				pts_client::$display->test_install_progress_update($downloaded_float);
				$last_float = $downloaded_float;
				break;
		}
	}
	private static function curl_status_callback($download_size, $downloaded)
	{
		static $last_float = -1;
		$downloaded_float = $download_size == 0 ? 0 : $downloaded / $download_size;

		if(abs($downloaded_float - $last_float) < 0.01)
		{
			return;
		}

		pts_client::$display->test_install_progress_update($downloaded_float);
		$last_float = $downloaded_float;
	}
	public static function client_startup()
	{
		if(($proxy_address = pts_config::read_user_config('PhoronixTestSuite/Options/Networking/ProxyAddress', false)) && ($proxy_port = pts_config::read_user_config('PhoronixTestSuite/Options/Networking/ProxyPort', false)))
		{
			self::$network_proxy['proxy'] = $proxy_address . ':' . $proxy_port;
			self::$network_proxy['address'] = $proxy_address;
			self::$network_proxy['port'] = $proxy_port;
		}
		else if(($env_proxy = getenv('http_proxy')) != false && count($env_proxy = pts_strings::colon_explode($env_proxy)) == 2)
		{
			self::$network_proxy['proxy'] = $env_proxy[0] . ':' . $env_proxy[1];
			self::$network_proxy['address'] = $env_proxy[0];
			self::$network_proxy['port'] = $env_proxy[1];
		}

		define('NETWORK_TIMEOUT', pts_config::read_user_config('PhoronixTestSuite/Options/Networking/Timeout', 20));

		if(ini_get('allow_url_fopen') == 'Off')
		{
			echo PHP_EOL . 'The allow_url_fopen option in your PHP configuration must be enabled for network support.' . PHP_EOL . PHP_EOL;
			self::$disable_network_support = true;
		}
		else if(pts_config::read_bool_config('PhoronixTestSuite/Options/Networking/NoNetworkCommunication', 'FALSE'))
		{
			echo PHP_EOL . 'Network Communication Is Disabled For Your User Configuration.' . PHP_EOL . PHP_EOL;
			self::$disable_network_support = true;
		}
		else if(pts_flags::no_network_communication() == true)
		{
			//echo PHP_EOL . 'Network Communication Is Disabled For Your User Configuration.' . PHP_EOL . PHP_EOL;
			self::$disable_network_support = true;
		}
		else
		{
			$server_response = pts_network::http_get_contents('http://www.phoronix-test-suite.com/PTS', false, false);

			if($server_response != 'PTS')
			{
				// Failed to connect to PTS server

				// As a last resort, see if it can resolve IP to Google.com as a test for Internet connectivity...
				// i.e. in case Phoronix server is down or some other issue, so just see if Google will resolve
				// If google.com fails to resolve, it will simply return the original string
				if(gethostbyname('google.com') == 'google.com')
				{
					echo PHP_EOL;
					trigger_error('No Network Connectivity', E_USER_WARNING);
					self::$disable_network_support = true;
				}
			}
		}

		if(pts_network::network_support_available() == false && ini_get('file_uploads') == 'Off')
		{
			echo PHP_EOL . 'The file_uploads option in your PHP configuration must be enabled for network support.' . PHP_EOL . PHP_EOL;
		}
	}
}

?>
