#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Pod::Usage;
use List::Util qw(sum);
use File::Basename;
#################################
# This takes a bam file as input and generates the coverage statistics on it.
#
#################################
my $BED = '';
my $BAM = '';
my $OUTFILE = '';
my @Interval;
my $SUM = '0';
my $ALL = '1';
my $help;
GetOptions(
        'bed=s'         =>\$BED,
        'bam=s'         =>\$BAM,
        'all=s'         =>\$ALL,
        'sum=s'         =>\$SUM,
        'int=s'         =>\@Interval,
        'out=s'         =>\$OUTFILE,
        'help|h'        =>\$help,
        )or pod2usage();

$help and pod2usage ();


if (!$BED){
        print STDERR "bed file is required -bed /data/khanlab/ref/GATK/hg19/RMS_Amplicon.bedtools.bed\n";
        die;
}
if (!$BAM){
        print STDERR "bam file is required -bam /data/khanlab/projects/working_DATA/Sample_RMS222_A_H3FHYAFXX/Sample_RMS222_A_H3FHYAFXX.trim.bam\n";
        die;
}
if (!$OUTFILE){
        print STDERR "output file is required -out /data/khanlab/projects/working_DATA/Sample_RMS222_A_H3FHYAFXX/Sample_RMS222_A_H3FHYAFXX.stats.txt\n";
        die;
}
if (!@Interval){
        print STDERR "You have to use argument -int atleast once.\n";
        die;
}
########################
# Main
########################
unless(open (IN, $BED)){
        print "Can not open the Bed file $BED\n";
        exit;
}

unless (open(OUT, ">$OUTFILE")){
        print "Can not open the output file $OUTFILE\nPlease check permissions\n\n ";
        exit;
}

my $tmp = basename($BAM, ".bam");
my $colsinBED=`head -1 $BED |awk -F "\t" '{print NF}'`;
$colsinBED = $colsinBED - 3;
print OUT "Chr\tStart\tStop";
foreach(1..$colsinBED){
        print OUT "\tHead$_";
}
#\tAmplicon\tTarget\tLength\tStrand\tGene\t
print OUT "\tBamfile\tLength\t\%Region Covered\tMin\tMax\tMean\tMedian\tQ1\tQ3";
foreach(@Interval){
        print OUT "\t% min X$_ Coverage";
}
print OUT "\n";
###################################
# Aggregate Stats on whole bed file
###################################

if($SUM eq 1){
        system("cut -f 1-3 $BED |sortBed -i - |mergeBed -i - |coverageBed -d -abam $BAM -b - >/scratch/$tmp.covinfo.all");
        my $line  = `cut -f 5 /scratch/$tmp.covinfo.all |awk '{if(\$1 >0)print \$0}'`;
        my @data = split("\n", $line);
        my $size = `cut -f 1-3 $BED |sortBed -i - |mergeBed -i - |awk -F'\t' 'BEGIN{SUM=0}{ SUM+=\$3-\$2 }END{print SUM}'`;
        chomp $size;
        if($size eq ($#data + 1 )){ # All bases have coverage
                @data =sort{$a <=> $b}(@data);
                my $mean  = mean(@data);
                my $median= Median(\@data);
                print OUT "Entire Bed Region\t-\t-";
                foreach(1..$colsinBED){
                        print OUT "\trecord$_";
                }
                print OUT "\t$tmp\t$size\t100\t$data[0]\t$data[$#data]\t$mean\t$median\t$data[$#data/4]\t$data[3*($#data)/4]";
                foreach(@Interval){
                        my $X   = Coverage($_, @data);
                        print OUT "\t$X";
                }
                print OUT "\n";
        }
        elsif($#data <0){ # Failed completely
                print OUT "Entire Bed Region\t-\t-";
                foreach(1..$colsinBED){
                        print OUT "\trecord$_";
                }
                print OUT "\t$tmp\t$size\t0\t0\t0\t0\t0\t0\t0";
                foreach(@Interval){
                        print OUT "\t0";
                }
                print OUT "\n";
        }
        else{ # Only some bases failed
                my $cov = sprintf "%.2f", (($#data - 1)/$size)*100;
                for (my $i=$#data; $i<$size; $i++){
                        push @data, 0;
                }
                @data =sort{$a <=> $b}(@data);
                my $mean = mean(@data);
                my $median= Median(\@data);
                print OUT "Entire Bed Region\t-\t-";
                foreach(1..$colsinBED){
                        print OUT "\trecord$_";
                }
                print OUT "\t$tmp\t$size\t$cov\t$data[0]\t$data[$#data]\t$mean\t$median\t$data[$#data/4]\t$data[3*($#data)/4]";
                foreach(@Interval){
                        my $X   = Coverage($_, @data);
                        print OUT "\t$X";
                }
                print OUT "\n";


        }
}
###################################
# Stats on every region in bed file
###################################

if ($ALL eq 1){
        system("cut -f 1-3 $BED |coverageBed -d -abam $BAM -b - >/scratch/$tmp.covinfo");
        while(<IN>){
                chomp;
                my @local = split ("\t", $_);
                my $line = `grep -P "$local[0]\t$local[1]\t$local[2]" /scratch/$tmp.covinfo |cut -f 5 |awk '{if(\$1 >0)print \$0}'`;
                my @data = split("\n", $line);
                my $size = $local[2] - $local[1];
                if($size eq ($#data + 1)){ # All bases have coverage
                        @data =sort{$a <=> $b}(@data);
                        my $mean  = mean(@data);
                        my $median= Median(\@data);
                        print OUT "$_\t$tmp\t$size\t100\t$data[0]\t$data[$#data]\t$mean\t$median\t$data[$#data/4]\t$data[3*($#data)/4]";
                        foreach(@Interval){
                                my $X   = Coverage($_, @data);
                                print OUT "\t$X";
                        }
                        print OUT "\n";
                }
                elsif($#data <0){ # Failed completely
                        print OUT "$_\t$tmp\t$size\t0\t0\t0\t0\t0\t0\t0";
                        foreach(@Interval){
                                print OUT "\t0";
                        }
                        print OUT "\n";
                }
                else{ # Only some bases failed
                        my $cov = sprintf "%.2f", (($#data - 1)/$size)*100;
                        for (my $i=$#data; $i<$size; $i++){
                                push @data, 0;
                        }
                        @data =sort{$a <=> $b}(@data);
                        my $mean = mean(@data);
                        my $median= Median(\@data);
                        print OUT "$_\t$tmp\t$size\t$cov\t$data[0]\t$data[$#data]\t$mean\t$median\t$data[$#data/4]\t$data[3*($#data)/4]";
                        foreach(@Interval){
                                my $X   = Coverage($_, @data);
                                print OUT "\t$X";
                        }
                        print OUT "\n";
                }
        }
        close IN;
        close OUT;
}
#unlink("/scratch/$tmp.covinfo.all");
#unlink("/scratch/$tmp.covinfo");
#######################
# END of MAIN
#######################

sub Coverage{
        my ($cov, @arr) = @_;
        my $out =0;
        foreach my $number(@arr){
                if($number >= $cov){
                        $out++;
                }
        }
        $out = sprintf "%.2f", ($out/($#arr + 1))*100;
        return $out;
}
sub mean{

        my $mean = @_ ? sum(@_) / @_ : 0;
        $mean = sprintf "%.0f", $mean;
        return $mean;
}

sub Median{
        my ($refdata) = @_;
        my $median;
        @$refdata = sort{$a<=>$b}@$refdata;
        my $count = @$refdata;
        if ($count %2){
                $median = $$refdata[int($count/2)];
        }
        else{
                $median = ($$refdata[$count/2]+ $$refdata[$count/2 -1])/2;
        }
        $median =sprintf "%.0f", $median;
        return $median;
}


=head1 SYNOPSIS

 $0 -bed /data/khanlab/ref/GATK/hg19/RMS_Amplicon.bedtools.bed -bam /data/khanlab/projects/working_DATA/Sample_RMS222_A_H3FHYAFXX/Sample_RMS222_A_H3FHYAFXX.trim.bam -out Sample_RMS222_A_H3FHYAFXX.QC.txt -int 10 -int 100 -int 500 -int 1000 -sum 1

 Usage:
        -h, -help, --help Print this message.
        -bed    Bed file containing the locations where statistics to be generated. (Required)
        -bam    Bam file on which the you whould like to generate the statistics, should be indexed. (Required)
        -all    0 if you dont want the statistics to be generated for every region in bed file.
                -all 0 -sum 1 will generate aggregate stat only. (Default generate stat on all positions)
        -sum    1 if you want aggregate entry for the whole bed file. (Default does not aggregate.)
                Overlapping regions in bed file will be merged to avoid overcounting.
        -int    %of Based covered with min intX. Can be specified multiple times. (Required)
        -out    Output file name. (Required)

 For questions or comments, please contact: Rajesh Patidar <rajbtpatidar@gmail.com>

=cut
