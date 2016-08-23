<?php
$os =""; 
if(empty($_GET['os'])){$os = "none";}else{$os = $_GET['os'];}
$home= $_SERVER['DOCUMENT_ROOT'].'/miops/dld';
$dirs = array("conf","filter","plugin/$os","plugin/comm","plugin/oracle");
$fileName = "conf_$os.lst";
$out="";
if(file_exists($fileName) && filemtime($fileName) > (time()-60) ){
	 $out = file_get_contents($fileName);
}else{
	foreach ($dirs as $dir1){
	 $path = "$home/$dir1";
	  if( ($handle = opendir("$path")) !== false){
	   while (($file=readdir($handle)) != false){
    			if (($file ==".") || ($file=="..")){ }else{
			$filename = "$path/$file";
			if(is_file($filename)){
				$digest = md5(file_get_contents($filename));
  				$out .=  "$dir1/$file=$digest\n";
			}
			}

		
 	 	}
		closedir($handle);
	 }
  }
  file_put_contents($fileName,$out);
}
echo $out;
