## File name: 	 cg-gen.py
## Description:  Generate component groups by recursively searching for
##				 component Id's below a given directory.
## Author:	 Phil Conner
## Output file:  cg_out.txt

# parse source file
import xml.etree.ElementTree as ET
tree = ET.parse('somefile.wxs')

# Create/open output file for writing
file_write = open("cg_out.txt", "a", newline="\n")

# dictionary for component group root directories and heads
cg_dict = {
	"cg1" : 
			{"head"    : ["<ComponentGroup\n", "\tId='MainFiles'>\n"],
			 "rootdir" : tree.find(".//Directory[@Id='INSTALLDIR']")},
	"cg2" : 
	        {"head"    : ["<ComponentGroup\n", "\tId='StartMenuShortcuts'>\n"],
			 "rootdir" : tree.find(".//Directory[@Id='ProgramMenuFolder']")},
}

# generate xml for component groups
for k,v in cg_dict.items():
	file_write.writelines(v["head"])
	for comp in v["rootdir"].findall(".//Component"):
		compId = comp.get('Id')
		content = "\t<ComponentRef Id='{0}'/>\n"
		current_line = content.format(compId)
		file_write.write(current_line)
	file_write.write("</ComponentGroup>\n")
	
file_write.close()
