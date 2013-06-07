#!/usr/bin/perl
#

##
## ===========================================================================
##
## Post process the FIO log files found in the indicated directory and create
## CSV files for each FIO log file. Combine the resulting CSV into one file.
##
## Arguments
##     $1 - directory path
##
## ===========================================================================

use File::Basename;
use List::Util qw[min max];

my $dir       = $ARGV[0];
my $lineCount = -1 >> 1;

chdir( $dir ) or die "Cannot chdir to $dir $!";
##
## search for the FIO bandwidth logs files and create a list. The assumption
## is that there is a corresponding iops and latency log file for each
## bandwidth log file
##
while ( <*_bw.log> )
{
    push @fileList, $_;
}

##
## interate through each FIO log and consolidate the job data
##
foreach $file ( sort @fileList )
{

    $baseJobname = fileparse( $file, qr/\Q_bw.log\E/ );

    my $intervalValue = 0;
    my $jobCount      = 0;

    ##
    ## collect the bandwidth data. add up all the job data. Note that the fio log files
    ## have a space after the ,
    ##
    my $index           = 0;
    my $maxTime         = -1 >> 1;
    my @bwReadInterval  = ();
    my @bwWriteInterval = ();
    $jobFile = $baseJobname . "_bw.log";
    open( FIOLOGFILE, $jobFile ) or die "Cannot open file $jobFile $!";
    while ( <FIOLOGFILE> )
    {
        chomp;
        @pieces = split( /, /, $_ );

        ##
        ## if this is the first time through this log save the first interval time
        ##
        if ( $index == 0 )
        {
            $intervalValue = ( $pieces[0] < 1000 ) ? $pieces[0] : int( $pieces[0] / 1000 );
        }

        ##
        ## Fio posts read and write data with the same interval time. If the current interval time
        ## equals the previous interval time then we have a read/write interval pair.
        ##
        if ( $pieces[0] == $maxTime )
        {

            if ( $pieces[2] == 0 )
            {
                $bwReadInterval[ $index - 1 ] += $pieces[1];
            }
            else
            {
                $bwWriteInterval[ $index - 1 ] += $pieces[1];
            }
        }
        else
        {

            ##
            ## Fio concatenates the data from each worker into a single data file. If the current interval
            ## time is less than the previous interval time then we have started on new job data.
            ##
            if ( $pieces[0] < $maxTime )
            {
                $index = 0;
                $jobCount++;
            }

            if ( $pieces[2] == 0 )
            {
                $bwReadInterval[$index] += $pieces[1];
            }
            else
            {
                $bwWriteInterval[$index] += $pieces[1];
            }

            $index++;
            $maxTime = $pieces[0];
        }
    }
    close( FIOLOGFILE );

    ##
    ## collect the iops data. add up all the job data
    ##
    $index   = 0;
    $maxTime = -1 >> 1;
    my @iopsReadInterval  = ();
    my @iopsWriteInterval = ();
    $jobFile = $baseJobname . "_iops.log";
    open( FIOLOGFILE, $jobFile ) or die "Cannot open file $jobFile $!";
    while ( <FIOLOGFILE> )
    {
        chomp;
        @pieces = split( /, /, $_ );

        if ( $pieces[0] == $maxTime )
        {

            if ( $pieces[2] == 0 )
            {
                $iopsReadInterval[ $index - 1 ] += $pieces[1];
            }
            else
            {
                $iopsWriteInterval[ $index - 1 ] += $pieces[1];
            }
        }
        else
        {

            if ( $pieces[0] < $maxTime )
            {
                $index = 0;
            }

            if ( $pieces[2] == 0 )
            {
                $iopsReadInterval[$index] += $pieces[1];
            }
            else
            {
                $iopsWriteInterval[$index] += $pieces[1];
            }

            $index++;
            $maxTime = $pieces[0];
        }
    }
    close( FIOLOGFILE );

    ##
    ## collect the latency data. average all the job data
    ##
    $index   = 0;
    $maxTime = -1 >> 1;
    my @latReadInterval  = ();
    my @latWriteInterval = ();
    $jobFile = $baseJobname . "_lat.log";
    open( FIOLOGFILE, $jobFile ) or die "Cannot open file $jobFile $!";

    while ( <FIOLOGFILE> )
    {
        chomp;
        @pieces = split( /, /, $_ );

        if ( $pieces[0] == $maxTime )
        {

            if ( $pieces[2] == 0 )
            {
                $latReadInterval[ $index - 1 ] += $pieces[1];
            }
            else
            {
                $latWriteInterval[ $index - 1 ] += $pieces[1];
            }
        }
        else
        {

            if ( $pieces[0] < $maxTime )
            {
                $index = 0;
            }

            if ( $pieces[2] == 0 )
            {
                $latReadInterval[$index] += $pieces[1];
            }
            else
            {
                $latWriteInterval[$index] += $pieces[1];
            }

            $index++;
            $maxTime = $pieces[0];
        }
    }
    close( FIOLOGFILE );

    ##
    ## output the consolidated data. print the csv header. save the csv file name for later
    ##
    my $outputName = $baseJobname . ".csv";
    push @csvList, $outputName;

    unlink( $outputName );
    open( CSVFILE, ">>" . $outputName );

    print CSVFILE $baseJobname, ",,,,,,,,,\n";
    print CSVFILE "interval,read_bw,write_bw,total_bw,read_iops,write_iops,total_iops,read_lat,write_lat,total_lat\n";

    my $intervalSize = max( scalar( @bwReadInterval ), scalar( @bwWriteInterval ) );
    for ( $index = 0 ; $index < $intervalSize ; $index++ )
    {

        print CSVFILE ( ( $index + 1 ) * $intervalValue ), ",", ( $bwReadInterval[$index] / 1024 ), ",", ( $bwWriteInterval[$index] / 1024 ), ",",
          ( ( $bwReadInterval[$index] + $bwWriteInterval[$index] ) / 1024 ), ",", $iopsReadInterval[$index], ",", $iopsWriteInterval[$index], ",",
          ( $iopsReadInterval[$index] + $iopsWriteInterval[$index] ), ",", ( $latReadInterval[$index] / $jobCount ), ",", ( $latWriteInterval[$index] / $jobCount ), ",",
          ( ( $latReadInterval[$index] + $latWriteInterval[$index] ) / $jobCount ), "\n";
    }
    close( CSVFILE );

    ##
    ## because of how fio works some log files may be longer than others. Find the
    ## shortest file so we can trim all the resulting csv files to the same length
    ##
    $count = `wc -l < $outputName`;
    die "wc failed: $?" if $?;
    chomp( $count );
    if ( $count < $lineCount )
    {
        $lineCount = $count;
    }
}

if ( @csvList > 0 )
{

    $csvString = "";

    ##
    ## trim each CSV file to the same length
    ##
    foreach $file ( sort @csvList )
    {
        system( "head -$lineCount $file > postprocess.tmp" );
        system( "mv postprocess.tmp $file" );

        $csvString .= $file . " ";
    }

    ##
    ## combine all the csv files we created
    ##
    system( "paste -d ',' $csvString > final_results.csv" );
}
