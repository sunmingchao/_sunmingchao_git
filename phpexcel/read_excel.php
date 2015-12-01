<?php
//2015-08-13 15:37:17

include_once('/usr/local/phpexcel/Classes/PHPExcel.php');
ini_set("display_errors","1");
$filepath="/usr/local/phpexcel/suoShuXianZhong.xls";
if(!file_exists($filepath)){
	exit("$filepath does not exists.");
}

function get_cell_data($phpexcel,$cell_id){
	$cell=$phpexcel->getActiveSheet()->getCell($cell_id)->getValue();
	$cell=addslashes($cell);
	//$cell=iconv("gb2312","utf-8",$cell);
	return $cell;
}


/* get excel version */
$reader=new  PHPExcel_Reader_Excel2007();
if(!$reader -> canRead($filepath)){
	$reader=new PHPExcel_Reader_Excel5();
	if(!$reader -> canRead($filepath)){
		exit("Read Excel File Failed.");
	}else{
		echo " - It is Excel5";
	}
}else{
	echo " - It is Excel2007";
}
echo "\n";


/* get excel size */
$phpexcel=$reader->load($filepath);
$current_sheet=$phpexcel->getSheet(0);
$col_num = $current_sheet->getHighestColumn(); 
$row_num = $current_sheet->getHighestRow(); 
echo " - Max column:".$col_num.", Max row:".$row_num."\n";


/* database connect */
$conn=mysql_connect("55cud.com:5649","root","%#@");
if($conn){
	echo " - Connect mysql OK!\n";
	mysql_query("SET NAMES utf-8");
	//mysql_select_db("bao");
}else{
	echo " - Connect mysql Failed!\n";
	die(mysql_error());
}



$field_excel_arr=array(
"title"=>"B",
"content"=>"J",
"qa_url"=>"M",
"goods_url"=>"L",
"answerer_icon"=>"H",
"addr"=>"F",
"questioner_icon"=>"E",
"questioner"=>"D",     
"question_type"=>"C",
"answerer_tel"=>"I",
"answerer"=>"G"   
);


$field_excel_arr=array(
"A"=>"aaa",
"B"=>"bbb",
"C"=>"ccc",
"D"=>"ddd",
"E"=>"eee"
);


echo " - Start insert.\n";
for($current_row = 1;$current_row <= $row_num;$current_row++){
	$sqlstr="";
	foreach($field_excel_arr as $k=>$v){
		$cell_id=$k.$current_row;
		$sqlstr.="$v='".get_cell_data($phpexcel,$cell_id)."',";
	}
	$sqlstr=substr($sqlstr,0,-1);
	//$sql="insert into bao.bao_goods_question set $sqlstr ;";
	$sql="set $sqlstr ;";

	echo $sql."\n\n";
	continue;	//just print

	if(mysql_query($sql,$conn)){
		echo " - Insert OK.\n";
	}else{
		echo " - Insert Failed.\n";
		echo mysql_error();
		break;
	}
}


mysql_close($conn);
exit;
//display 5 lines.
for($current_row = 1;$current_row <= $row_num;$current_row++){
	for($current_clomun= 'A';$current_clomun <= $col_num; $current_clomun++){ 
		$cell_id=$current_clomun.$current_row;
		$cell=$phpexcel->getActiveSheet()->getCell($cell_id)->getValue();
		$cell=addslashes($cell);
		echo $cell." | " ;
	}
	echo "\n\n";
	if($current_row == 5) break;
}

?>
