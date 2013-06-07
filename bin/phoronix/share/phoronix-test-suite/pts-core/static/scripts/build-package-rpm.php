<?php

/*
	Phoronix Test Suite
	URLs: http://www.phoronix.com, http://www.phoronix-test-suite.com/
	Copyright (C) 2008 - 2011, Phoronix Media
	Copyright (C) 2008, Andrew Schofield

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

if(!is_file("phoronix-test-suite") || !is_dir("pts/") || !is_dir("pts-core/"))
{
       echo "\nYou must run this script from the root directory of the phoronix-test-suite/ folder!\n";
       echo "Example: php5 pts-core/scripts/package-build-rpm.php\n";
       exit(0);
}
@require("pts-core/pts-core.php");

if(!defined("PTS_VERSION"))
{
       echo "\nERROR: The Phoronix Test Suite version wasn't found!\n";
       exit(0);
}

shell_exec("rm -rf /tmp/pts-rpm-builder/");
shell_exec("mkdir -p /tmp/pts-rpm-builder/{BUILD,RPMS,S{OURCE,PEC,RPM}S,phoronix-test-suite-" . PTS_VERSION . "}");
shell_exec("cp -R ./ /tmp/pts-rpm-builder/phoronix-test-suite-" . PTS_VERSION . "/");
shell_exec("tar --exclude=.git -C /tmp/pts-rpm-builder/ -cjvf /tmp/pts-rpm-builder/SOURCES/phoronix-test-suite-" . PTS_VERSION . ".tar.bz2 phoronix-test-suite-" . PTS_VERSION . "/");

$spec_file = "Summary: A Comprehensive Linux Benchmarking System\n";
$spec_file .= "Name: phoronix-test-suite\n";
$spec_file .= "Version: " . PTS_VERSION . "\n";
$spec_file .= "Release: 1\n";
$spec_file .= "License: GPL\n";
$spec_file .= "Group: Utilities\n";
$spec_file .= "URL: http://www.phoronix-test-suite.com/\n";
$spec_file .= "Source: phoronix-test-suite-" . PTS_VERSION . ".tar.bz2\n";
$spec_file .= "Packager: Phoronix Media <trondheim-pts@phoronix-test-suite.com>\n";
$spec_file .= "Requires: php-cli, php-gd\n";
$spec_file .= "BuildArch: noarch\n";
$spec_file .= "BuildRoot: %{_tmppath}/%{name}-%{version}-root\n";
$spec_file .= "%description\n";
$spec_file .= @file_get_contents("pts-core/static/short-description.txt") . "\n";
$spec_file .= "%prep\n";
$spec_file .= "%setup -q\n";
$spec_file .= "%build\n";
$spec_file .= "%install\n";
$spec_file .= "rm -rf %{buildroot}\n";
$spec_file .= "./install-sh %{buildroot}/usr\n";
$spec_file .= "sed -i 's|%buildroot||g' %buildroot%_bindir/phoronix-test-suite\n";
$spec_file .= "%clean\n";
$spec_file .= "rm -rf %{buildroot}\n";
$spec_file .= "%files\n";
$spec_file .= "%{_bindir}/phoronix-test-suite\n";
$spec_file .= "%{_datadir}/phoronix-test-suite/*\n";
$spec_file .= "%{_datadir}/doc/*\n";
$spec_file .= "%changelog\n";
$spec_file .= "* Fri Jun 06 2008 Andrew Schofield <andrew_s@fahmon.net>\n";
$spec_file .= "- Initial release.";

file_put_contents("/tmp/pts-rpm-builder/SPECS/pts.spec", $spec_file);
shell_exec("mv -f " . pts_client::user_home_directory() . ".rpmmacros /tmp/pts-rpm-builder");
file_put_contents(pts_client::user_home_directory() .".rpmmacros", "%_topdir /tmp/pts-rpm-builder");
shell_exec("rpmbuild -ba --verbose /tmp/pts-rpm-builder/SPECS/pts.spec");
shell_exec("cp /tmp/pts-rpm-builder/RPMS/noarch/phoronix-test-suite-" . PTS_VERSION . "-1.noarch.rpm ./");
shell_exec("rm -f " . pts_client::user_home_directory() . "/.rpmmacros");
shell_exec("mv -f /tmp/pts-rpm-builder/.rpmmacros " . pts_client::user_home_directory());
shell_exec("rm -rf /tmp/pts-rpm-builder");

?>
