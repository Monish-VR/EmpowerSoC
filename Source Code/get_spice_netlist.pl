#!/usr/bin/perl

my $ScriptLoc = "/usr/lib/EmpowerSoc";
my $moduleName;

opendir(DIR, '../synthesis') or die "Couldn't open directory, $!";
my @blifFile = grep(/\.blif$/,readdir(DIR));
#print $blifFile[0]."\n";
close(DIR);

# Reading the .blif file to get the module name
open(FILE, '<', "../synthesis/$blifFile[0]")
  or die "Could not open file $blifFile[0]- $!";

while (my $row = <FILE>) {
  if(index($row,".model") == 0)
  {
  	my @array = split(" ", $row);
  	#print "Module name - $array[1]\n";
  	$moduleName=$array[1];
  	last;
  }
}
close(FILE);

# Calling create_magic_load_file.sh script to create load_<moduleName>.tcl file
system("$ScriptLoc/create_magic_load_file.sh .. $moduleName"); 

# Running Magic tool to create .ext files for subcomponents 
my $command = "magic -dnull -noconsole ".$moduleName.".mag<<EOF
source load_".$moduleName.".tcl
extract all
quit -noprompt
EOF";
system($command);

# Using Magic tool to extract .spice files of subcomponents
opendir(DIR, '.') or die "Couldn't open directory, $!";
my $files="";
foreach (sort grep(/\.ext$/,readdir(DIR))) {
    $files=$files."ext2spice $_\n";
}
$files=$files."quit -noprompt\n";
$files =~ s/\.ext//g;
#print $files;
$command = "magic -noconsole -nowrapper ".$moduleName.".mag<<EOF
$files
EOF";
system($command);

# Clean SPICE files for NGSpice compatibility
print "Cleaning SPICE files for NGSpice compatibility...\n";
opendir(DIR, '.') or die "Couldn't open directory, $!";
my @spiceFiles = grep(/\.spice$/,readdir(DIR));
closedir(DIR);

foreach my $spiceFile (@spiceFiles) {
    print "Processing $spiceFile...\n";
    
    # Create cleaned version
    my $tempFile = "$spiceFile.tmp";
    open(INPUT, '<', $spiceFile) or die "Could not open $spiceFile: $!";
    open(OUTPUT, '>', $tempFile) or die "Could not create $tempFile: $!";
    
    while (my $line = <INPUT>) {
        # Remove **floating annotations
        $line =~ s/\s*\*\*floating\s*//g;
        # Remove other problematic Magic annotations
        $line =~ s/\s*\*\*\w+\s*$//g;
        # Clean up any trailing whitespace
        $line =~ s/\s+$//g;
        # Add back the newline
        $line .= "\n" if $line !~ /\n$/;
        print OUTPUT $line;
    }
    
    close(INPUT);
    close(OUTPUT);
    
    # Replace original with cleaned version
    system("mv $tempFile $spiceFile");
}

# Clean up model files to remove unsupported NGSpice parameters
print "Cleaning model files for NGSpice compatibility...\n";
if (-f "../synthesis/SampleLib.mod") {
    # Create backup
    system("cp ../synthesis/SampleLib.mod ../synthesis/SampleLib.mod.backup");
    
    # Remove unsupported parameters
    system("sed -i 's/acm=[0-9]*//g' ../synthesis/SampleLib.mod");
    system("sed -i 's/xl=[0-9.e-]*//g' ../synthesis/SampleLib.mod");
    system("sed -i 's/xw=[0-9.e-]*//g' ../synthesis/SampleLib.mod");
    system("sed -i 's/version=[0-9.]*//g' ../synthesis/SampleLib.mod");
    system("sed -i 's/tnom=[0-9]*//g' ../synthesis/SampleLib.mod");
    
    # Clean up any double spaces left by parameter removal
    system("sed -i 's/  */ /g' ../synthesis/SampleLib.mod");
    system("sed -i 's/ *\$//' ../synthesis/SampleLib.mod");
    
    print "Model file cleaned. Backup saved as SampleLib.mod.backup\n";
}

# Storing the spice netlists inside EmpowerSOC/spice_netlist directory
if( -d "../EmpowerSOC/spice_netlist")
{
  system("rm -rf ../EmpowerSOC/spice_netlist");
}
system("mkdir ../EmpowerSOC/spice_netlist");
system("mv *.spice ../EmpowerSOC/spice_netlist");

print "SPICE files cleaned and moved to ../EmpowerSOC/spice_netlist/\n";
print "NGSpice compatibility issues should now be resolved.\n";
