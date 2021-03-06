#library(rvest)
#library(data.table)
#library(jsonlite)
#library(httr)
#library(dplyr)
#library(readxl)

# setting locale for accented character handling
ifelse(.Platform$OS.type == 'windows', 
       Sys.setlocale(category = 'LC_ALL', locale = 'Hungarian'), 
       Sys.setlocale(category = 'LC_ALL', locale = 'hu_HU.utf8'))



Packages          <- c('dplyr','rvest','jsonlite','ggplot2','data.table','httr','readxl')
InstalledPackages     <- rownames(installed.packages())

# install/load packages
sapply(Packages, function(p)  {
  if (!(p %in% (InstalledPackages))) { install.packages(p, quiet = TRUE) } 
  library(p, character.only = TRUE, quietly = TRUE, logical.return = TRUE)
} )


#read in the data, then you do not need to scrape :)
valkor_results_2018_df<-data.table(read.csv('https://raw.githubusercontent.com/Zsopi/Hungarian-election-data-scraping-and-modeling/master/valkor_results_final_2018.csv'))
valker_results_2018_df<-data.table(read.csv('https://raw.githubusercontent.com/Zsopi/Hungarian-election-data-scraping-and-modeling/master/valker_results_final_2018.csv'))


#setting working directory, change it as desired, otherwise uses default working directory
wd<-getwd()
#wd<-'C:/Users/Zsopi/Google Drive/R/Scraping'

####################################scraping attempt starts here

#get high level urls (basically initial letters of settlements, from first html table, see webpage input)
url_ini<-read_html('http://www.valasztas.hu/dyn/pv18/szavossz/hu/TK/szkkivtka.html')

urls_highlevel<-url_ini%>%
        html_nodes("table:nth-of-type(1) a")%>%html_attr("href")%>%head(-1)

#adding missing first letter (a) reference
urls_highlevel<-c("szkkivtka.html",urls_highlevel)

urls_highlevel<-paste0('http://www.valasztas.hu/dyn/pv18/szavossz/hu/TK/',urls_highlevel)


#function returns list of links from nth (second) html table of input url
getlinks_from_t2<-function (url,n=2){
  
        download.file(url, destfile = "scrapedpage.html", quiet=TRUE)
        t<-read_html("scrapedpage.html")%>%html_nodes(paste0("table:nth-of-type(",n,") a"))%>%html_attr("href")      
        return(t)
        
}

#get mid-level urls (linkt to individual settlement results)
urls_midlevel<-lapply(urls_highlevel,getlinks_from_t2)

urls_midlevel<-unlist(urls_midlevel)

urls_midlevel<-gsub('..','',urls_midlevel,fixed = T)

urls_midlevel<-paste0('http://www.valasztas.hu/dyn/pv18/szavossz/hu/',urls_midlevel)


#get final level urls (individual voting place resulst, "szavazókör")

getlinks_final<-function (url) {
        t<-paste0(gsub('szkkiv.html','',url),getlinks_from_t2(url))
        return(t)
}

urls_all_indiv<-lapply(urls_midlevel,getlinks_final)

#this should have a list of 10285 elements, with the urls of the result page for each individual voting place ("szavazókör")
urls_all_indiv<-unlist(urls_all_indiv)

#sorting the result
urls_all_indiv<-sort(urls_all_indiv)

#function to get id of individual voting places
get_id_valkor<-function(url) {
        download.file(url, destfile = "scrapedpage.html", quiet=TRUE)
        t<-read_html("scrapedpage.html")%>%html_nodes("h2")%>%html_text() 
        return(t)
        
}

#downloading individual voting place ids
valkor_id_list<-lapply(urls_all_indiv,get_id_valkor)

#constructing voting place id datatable
valkor_id_df<-rbindlist(lapply(valkor_id_list, function(x) data.frame(id1=x[[1]],id2=x[[2]],id3=x[[3]])))

valkor_id_df<-valkor_id_df[,1:2]

valkor_id_df[,id3:=data.table(gsub("\r\n", ";", valkor_id_df$id1))]
valkor_id_df[,id3:=data.table(gsub(";leadott", "", valkor_id_df$id3))]
valkor_id_df[,id3:=data.frame(do.call("rbind", strsplit(valkor_id_df$id3, ";")))[,2]]

#Extracting variables from text
valkor_id_df[,MEGYE:=data.frame(do.call("rbind", strsplit(sub("\\s+", ";", valkor_id_df$id2), ";")))[,1]]
valkor_id_df[,OEVK:=data.table(gsub("\\D+", "", valkor_id_df$id2))]
#SZEKHELY
valkor_id_df[,TELEPUL:=data.frame(do.call("rbind", strsplit(sub("\\s+", ";", valkor_id_df$id3), ";")))[,1]]
valkor_id_df[,VALKOR:=data.table(gsub("\\D+", "", valkor_id_df$id1))]
valkor_id_df[TELEPUL=='Budapest',TELEPUL_BP:=data.table(regmatches(valkor_id_df$id3,regexpr("Budapest[[:space:]].+ker\\.",valkor_id_df$id3)))]

valkor_id_df[MEGYE=='BUDAPEST',TELEPUL_BP:=data.table(regmatches(valkor_id_df$id3,regexpr("Budapest[[:space:]].+kerület",valkor_id_df$id3)))]

valkor_id_df[TELEPUL=='Budapest',TELEPUL:=TELEPUL_BP]


#turning everything into character vector
valkor_id_df<-valkor_id_df[,lapply(.SD,function(x) as.character(x))]


###############SCRAPING VOTING PLACE RESULTS
#scraping initial voting place results from web (results in large list of lists of tables)
#happens several parts to reduce  chance of timeout
valkor_results1<-lapply(urls_all_indiv[1:1000], function(url) read_html(url)%>%html_table())
valkor_results2<-lapply(urls_all_indiv[1001:2000], function(url) read_html(url)%>%html_table())
valkor_results3<-lapply(urls_all_indiv[2001:3000], function(url) read_html(url)%>%html_table())
valkor_results4<-lapply(urls_all_indiv[3001:4000], function(url) read_html(url)%>%html_table())
valkor_results5<-lapply(urls_all_indiv[4001:5000], function(url) read_html(url)%>%html_table())
valkor_results6<-lapply(urls_all_indiv[5001:6000], function(url) read_html(url)%>%html_table())
valkor_results7<-lapply(urls_all_indiv[6001:7000], function(url) read_html(url)%>%html_table())
valkor_results8<-lapply(urls_all_indiv[7001:8000], function(url) read_html(url)%>%html_table())
valkor_results9<-lapply(urls_all_indiv[8001:9000], function(url) read_html(url)%>%html_table())
valkor_results10<-lapply(urls_all_indiv[9001:length(urls_all_indiv)], function(url) read_html(url)%>%html_table())

#binding together results
valkor_results_final<-c(valkor_results1,valkor_results2,valkor_results3,valkor_results4,valkor_results5,valkor_results6,valkor_results7,valkor_results8,valkor_results9,valkor_results10)

#valkor_results_final<-c(noquote(paste0('valkor_results',1:10,",")),valkor_results10)


#setting variable names for individual voting place dataframe
valkor_data_names<-c('MEGYE','OEVK','SZEKHELY','TELEPUL','VALKOR','AE','FE','FE_pct','BE','GE','C','EE','IE','JE','OE','KE','LE','ME','NE','NOSTAMP_LST','SZVLP_LST','SZVLP_LST_LTR','ERVTL_LST','ERV_LST','KULKEP_ATJEL','BOL','GL', 'FIDESZ_egy','JOBBIK_egy','MSZP_egy','DK_egy','LMP_egy','MOMENTUM_egy','EGYUTT_egy','MKKP_egy','FUGGETLEN_egy','MAS_egy',
                     'FIDESZ_egy_pct','JOBBIK_egy_pct','MSZP_egy_pct','DK_egy_pct','LMP_egy_pct','MOMENTUM_egy_pct','EGYUTT_egy_pct','MKKP_egy_pct','FUGGETLEN_egy_pct','MAS_egy_pct',
                     'FIDESZ_lst','JOBBIK_lst','MSZP_lst','DK_lst','LMP_lst','MOMENTUM_lst','EGYUTT_lst','MKKP_lst','FUGGETLEN_lst','MAS_lst',
                     'FIDESZ_lst_pct','JOBBIK_lst_pct','MSZP_lst_pct','DK_lst_pct','LMP_lst_pct','MOMENTUM_lst_pct','EGYUTT_lst_pct','MKKP_lst_pct','FUGGETLEN_lst_pct','MAS_lst_pct',
                     'FIDESZ_egy_jlt','JOBBIK_egy_jlt','MSZP_egy_jlt','DK_egy_jlt','LMP_egy_jlt','MOMENTUM_egy_jlt','EGYUTT_egy_jlt','MKKP_egy_jlt','FUGGETLEN_egy_jlt','MAS_egy_jlt')

party_names<-c('FIDESZ','JOBBIK','MSZP','DK','LMP','MOMENTUM','EGYUTT','MKKP','FUGGETLEN')
valker_names_egy<-paste0(party_names,'_egy')
valker_names_egy_pct<-paste0(party_names,'_egy_pct')
valker_names_lst<-paste0(party_names,'_lst')
valker_names_lst_pct<-paste0(party_names,'_lst_pct')
valker_names_egy_jlt<-paste0(party_names,'_egy_jlt')

party_names_official<-c('FIDESZ-KDNP','JOBBIK','MSZP-PÁRBESZÉD','DK','LMP','MOMENTUM','EGYÜTT','MKKP','Független jelölt')
party_names_official_lst<-c('FIDESZ - MAGYAR POLGÁRI SZÖVETSÉG-KERESZTÉNYDEMOKRATA NÉPPÁRT','JOBBIK MAGYARORSZÁGÉRT MOZGALOM','MAGYAR SZOCIALISTA PÁRT-PÁRBESZÉD MAGYARORSZÁGÉRT PÁRT','DEMOKRATIKUS KOALÍCIÓ','LEHET MÁS A POLITIKA','MOMENTUM MOZGALOM','EGYÜTT - A KORSZAKVÁLTÓK PÁRTJA','MAGYAR KÉTFARKÚ KUTYA PÁRT')


#example table
temp_table<-valkor_results_final[[12]][[7]]
temp_table<-valkor_results1[[12]][[8]]
View(temp_table)


#defining function to construct data table from initial voting place download results
get_val_kor_results<-function(indiv_valkor_tables_list) {
  
  #creating empty data.frame for results
  df <- read.csv(text="",col.names = valkor_data_names, colClasses = 'character')
  temp_df<-setNames(data.frame(matrix(ncol = length(valkor_data_names), nrow = 1)), valkor_data_names)
  temp_df[]<-lapply(temp_df, function(x) as.character(x))
  setDT(temp_df)
  #get individual tables from valkor list of tables in a loop
  #identify table by variable names/content
  #put results in appropriate cells in temporary dataframe
  
  for (i in 2:length(indiv_valkor_tables_list)) {
    temp_table<-indiv_valkor_tables_list[[i]]        
    if ('AE'%in%temp_table[1,]) {temp_df[1,'AE']<-as.character(temp_table[2,which(temp_table[1,] =='AE')])}
    if ('FE'%in%temp_table[1,]) {temp_df[1,'FE']<-as.character(temp_table[2,which(temp_table[1,] =='FE')])}
    if ('BE'%in%temp_table[1,]) {temp_df[1,'BE']<-as.character(temp_table[2,which(temp_table[1,] =='BE')])}
    if ('BOE'%in%temp_table[1,]) {temp_df[1,'BE']<-as.character(temp_table[2,which(temp_table[1,] =='BOE')])}
    if ('GE'%in%temp_table[1,]) {temp_df[1,'GE']<-as.character(temp_table[2,which(temp_table[1,] =='GE')])}
    if ('C'%in%temp_table[1,]) {temp_df[1,'C']<-as.character(temp_table[2,which(temp_table[1,] =='C')])}
    if ('EE'%in%temp_table[1,]) {temp_df[1,'EE']<-as.character(temp_table[2,which(temp_table[1,] =='EE')])}
    if ('IE'%in%temp_table[1,]) {temp_df[1,'IE']<-as.character(temp_table[2,which(temp_table[1,] =='IE')])}
    if ('JE'%in%temp_table[1,]) {temp_df[1,'JE']<-as.character(temp_table[2,which(temp_table[1,] =='JE')])}
    if ('OE'%in%temp_table[1,]) {temp_df[1,'OE']<-as.character(temp_table[2,which(temp_table[1,] =='OE')])}
    if ('KE'%in%temp_table[1,]) {temp_df[1,'KE']<-as.character(temp_table[2,which(temp_table[1,] =='KE')])}
    if ('LE'%in%temp_table[1,]) {temp_df[1,'LE']<-as.character(temp_table[2,which(temp_table[1,] =='LE')])}
    if ('ME'%in%temp_table[1,]) {temp_df[1,'ME']<-as.character(temp_table[2,which(temp_table[1,] =='ME')])}
    if ('NE'%in%temp_table[1,]) {temp_df[1,'NE']<-as.character(temp_table[2,which(temp_table[1,] =='NE')])}
    
    
    if (!is.na(temp_table[1,1])) {if (temp_table[1,1]=='Összesen'&length(temp_table[1,])==7) {temp_df[1,c('NOSTAMP_LST','SZVLP_LST','SZVLP_LST_LTR','ERVTL_LST','ERV_LST'):=as.list(as.character(temp_table[2,3:7]))]}}
    if (!is.na(temp_table[1,1])) {if (temp_table[1,1]=='Összesen'&length(temp_table[1,])==8) {temp_df[1,c('NOSTAMP_LST','SZVLP_LST','SZVLP_LST_LTR','ERVTL_LST','ERV_LST'):=as.list(as.character(temp_table[2,4:8]))]}}
    if (!is.na(temp_df[1,SZVLP_LST_LTR])&as.character(temp_df[1,SZVLP_LST_LTR])=='-'){temp_df[,SZVLP_LST_LTR:=as.character(temp_table[2,6])]}
    
    #if (!is.na(temp_table[1,1])) {if (temp_table[1,1]=='Összesen'&length(temp_table[1,])==8) {temp_df[1,KULKEP_ATJEL:=(as.character(temp_table[1,4]))]}}
    if (!is.na(temp_table[1,2])) {if (temp_table[1,2]=='IL') {temp_df[1,KULKEP_ATJEL:=(as.character(temp_table[2,2]))]}}
    
    
    if (names(temp_table)[2]=='A jelölt neve') {
      names(temp_table)<-c('sorszam','nev','szervezet','szav')
      
      for (j in 1:length(party_names)) {
        temp_df[1,valker_names_egy[j]:=ifelse(party_names_official[j]%in%temp_table$szervezet,as.character(temp_table[temp_table$szervezet==party_names_official[j],'szav']),NA)]
        temp_df[1,valker_names_egy_jlt[j]:=ifelse(party_names_official[j]%in%temp_table$szervezet,as.character(temp_table[temp_table$szervezet==party_names_official[j],'nev']),NA)]
        
      }
    }
    
    if (grepl('A pártlista neve',names(temp_table)[2])) {
      names(temp_table)<-c('sorszam','nev','szav')
      
      for (k in 1:length(party_names)) {
        temp_df[1,valker_names_lst[k]:=ifelse(party_names_official_lst[k]%in%temp_table$nev,as.character(temp_table[temp_table$nev==party_names_official_lst[k],'szav']),NA)]
        
      }
  
    }
  }
  
  return(temp_df)
}

#extracting voting place data to data table, adding ids
valkor_results_df<-rbindlist(lapply(valkor_results_final,get_val_kor_results))

setDT[valkor_results_df]

t<-get_val_kor_results(valkor_results_final[[1]])
View(t)


tempnames<-c('MEGYE','OEVK','TELEPUL','VALKOR')
valkor_results_df[,(tempnames):=valkor_id_df[,tempnames,with=F]]
tempnames<-NULL


################tidying up data table
#swapping whitespace plus % sign to just % sign in some columns
valkor_results_df[,c('FE','GE','JE'):=.(sub('[[:space:]]\\%$','%',FE),sub('[[:space:]]\\%$','%',GE),sub('[[:space:]]\\%$','%',JE))]

#deleting whitespace+number+%sign combinations from the end of the string
valkor_results_df[,c('FE','GE','JE'):=.(sub('[[:space:]][^[:space:]]*\\%$','',FE),sub('[[:space:]][^[:space:]]*\\%$','',GE),sub('[[:space:]][^[:space:]]*\\%$','',JE))]

#deleting all spaces
valkor_results_df[,names(valkor_results_df[,AE:MAS_lst_pct]):=lapply(.SD,function(x) gsub('[[:space:]]','',as.character(x))),.SDcols=AE:MAS_lst_pct]

#turning everything except names into numeric characters
valkor_results_df[,names(valkor_results_df[,AE:MAS_lst_pct]):=lapply(.SD,function(x) as.numeric(as.character(x))),.SDcols=AE:MAS_lst_pct]

#correcting different representation in case of districts with foreign votes
#valkor_results_df[!is.na(C),SZVLP_LST_LTR:=SZVLP_LST_LTR-SZVLP_LST]
#valkor_results_df[!is.na(C),SZVLP_LST:=SZVLP_LST_LTR+SZVLP_LST]

#calculating "other" votes (not main parties), and their percent share for individuals
valkor_results_df[,MAS_egy:=NE-(FIDESZ_egy+JOBBIK_egy+MSZP_egy+DK_egy+LMP_egy+MOMENTUM_egy+EGYUTT_egy+MKKP_egy)]
valkor_results_df[,MAS_egy_pct:=MAS_egy/NE]

#calculating "other" votes (not main parties), and their percent share for lists
valkor_results_df[,MAS_lst:=ERV_LST-(FIDESZ_lst+JOBBIK_lst+MSZP_lst+DK_lst+LMP_lst+MOMENTUM_lst+EGYUTT_lst+MKKP_lst)]
valkor_results_df[,MAS_egy_pct:=MAS_egy/ERV_LST]

#calculating ratios
valkor_results_df[,FE_pct:=FE/AE]
valkor_results_df[,names(valkor_results_df[,FIDESZ_egy_pct:MAS_egy_pct]):=lapply(.SD,function(x) x/NE),.SDcols=(FIDESZ_egy:MAS_egy)]
valkor_results_df[,names(valkor_results_df[,FIDESZ_lst_pct:MAS_lst_pct]):=lapply(.SD,function(x) x/ERV_LST),.SDcols=(FIDESZ_lst:MAS_lst)]

#some new variables
valkor_results_df[,inval_egy_pct:=ME/(ME+NE)]
valkor_results_df[,inval_lst_pct:=(ERVTL_LST)/(ERVTL_LST+ERV_LST)]
valkor_results_df[,LEFTLIB_OPP_lst_pct:=(MSZP_lst_pct+LMP_lst_pct+DK_lst_pct+MOMENTUM_lst_pct+EGYUTT_lst_pct)]

if (!('X'%in%names(valkor_results_df))) {valkor_results_df<-cbind(X=(1:10285),valkor_results_df)}

#this works, but only if locale is set to Hungarian. Spreadsheet needs to be saved in old excel (xls) format
#opp_obs<-read_excel('C:/Users/Zsopi/Google Drive/R/valasztas/opp_obs_xls.xls')
#write.csv(opp_obs,'opp_obs.csv')

# reading in opposition observer csv data from github
opp_obs<-read.csv('https://raw.githubusercontent.com/Zsopi/Hungarian-election-data-scraping-and-modeling/master/opp_obs.csv')
if (('X'%in%names(opp_obs))) {opp_obs$X<-NULL}
setDT(opp_obs)

opp_obs[,VALKOR:=sprintf("%03d", VALKOR)]

setkey(opp_obs,TELEPUL_L,VALKOR)

match_table<-valkor_results_df[,X:VALKOR]

match_table[,TELEPUL_L:=toupper(TELEPUL)]

match_table[,BP_L:=gsub('. KERÜLET','',match_table$TELEPUL_L)]

match_table[,BP_L:=gsub('BUDAPEST ','',match_table$BP_L)]

match_table[MEGYE=='BUDAPEST',BP_DISTR:=as.numeric(as.roman(match_table[MEGYE=='BUDAPEST',]$BP_L))]

match_table[MEGYE=='BUDAPEST',TELEPUL_L:=paste('BUDAPEST',sprintf("%02d", BP_DISTR),sep = " ")]

setkey(match_table,TELEPUL_L,VALKOR)

match_table_final<-merge(match_table,opp_obs, all.x=TRUE)[order(X)]

View(match_table_final)

###############
valkor_results_2018_df<-cbind(valkor_results_df[,X:VALKOR], data.table(match_table_final[,Ellenzekidelegalt:NINCSELLENZEK]),valkor_results_df[,AE:LEFTLIB_OPP_lst_pct])

#read in preliminary data to find out ditrict where there was no result published initially
valkor_results_2018_prelim_df<-data.table(read.csv('https://raw.githubusercontent.com/Zsopi/Hungarian-election-data-scraping-and-modeling/master/valkor_results_prelim_2018.csv'))

valkor_results_2018_df[,foreign_dummy:=ifelse(is.na(valkor_results_2018_prelim_df$NE),1,0)]

#summary of list votes
listresults_districts<-valkor_results_2018_df[,lapply(.SD, sum, na.rm=T),.SDcols=c('FIDESZ_lst','JOBBIK_lst','MSZP_lst','DK_lst','LMP_lst','MOMENTUM_lst','EGYUTT_lst','MKKP_lst','MAS_lst','ERVTL_LST','ERV_LST'),by=.(MEGYE,OEVK)]
listresults_districts[,c(names(valkor_results_2018_df[,FIDESZ_lst_pct:MKKP_lst_pct]),'MAS_lst_pct'):=lapply(.SD,function(x) x/ERV_LST),.SDcols=(FIDESZ_lst:MAS_lst)]
listresults_districts[,OEVK:=as.numeric(as.character(OEVK))]

####settlement aggregation
listresults_settlements<-valkor_results_2018_df[,lapply(.SD, sum, na.rm=T),.SDcols=c('FIDESZ_lst','JOBBIK_lst','MSZP_lst','DK_lst','LMP_lst','MOMENTUM_lst','EGYUTT_lst','MKKP_lst','MAS_lst','ERVTL_LST','ERV_LST'),by=.(TELEPUL)]
listresults_settlements_pct<-cbind(listresults_settlements$TELEPUL,listresults_settlements[,lapply(.SD, function (x) x/ERV_LST),.SDcols=c('FIDESZ_lst','JOBBIK_lst','MSZP_lst','DK_lst','LMP_lst','MOMENTUM_lst','EGYUTT_lst','MKKP_lst','MAS_lst','ERVTL_LST','ERV_LST')])
listresults_settlements_pct$ERV_LST<-listresults_settlements$ERV_LST
listresults_settlements_pct<-cbind(listresults_settlements_pct,divis=(valkor_results_2018_df[foreing_dummy==0,][,max(FIDESZ_lst_pct)-min(FIDESZ_lst_pct),by=TELEPUL])[,2],divis_std=(valkor_results_2018_df[foreing_dummy==0,][,sd(FIDESZ_lst_pct),by=TELEPUL])[,2])


egy_results_settlements<-valkor_results_2018_df[,lapply(.SD, sum, na.rm=T),.SDcols=c('FIDESZ_egy','JOBBIK_egy','MSZP_egy','DK_egy','LMP_egy','MOMENTUM_egy','EGYUTT_egy','MKKP_egy','MAS_egy','ME','NE'),by=.(TELEPUL)]
egy_results_settlements_pct<-cbind(egy_results_settlements$TELEPUL,egy_results_settlements[,lapply(.SD, function (x) x/NE),.SDcols=c('FIDESZ_egy','JOBBIK_egy','MSZP_egy','DK_egy','LMP_egy','MOMENTUM_egy','EGYUTT_egy','MKKP_egy','MAS_egy','ME','NE')])
egy_results_settlements_pct$NE<-egy_results_settlements$NE

setkey(listresults_districts,MEGYE,OEVK)

################Writing resulting data tables
write.csv(valkor_results_2018_df,'valkor_results_final_2018.csv')
valkor_results_2018_df_t<-read.csv(paste0(wd,'/valkor_results_final_2018.csv'))
View(valkor_results_2018_df_t)

write.csv(listresults_settlements_pct,'listresults_settlements_pct.csv')
write.csv(egy_results_settlements_pct,'egy_settlements_pct.csv')


#template for getting vote ratio in an individual settlement
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(FIDESZ_egy,na.rm=T)/sum(FE,na.rm=T))]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(ERV_LST,na.rm=T))]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(AE,na.rm=T))]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(FIDESZ_lst,na.rm=T))]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(LMP_lst,na.rm=T))]

valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(FIDESZ_lst,na.rm=T)/sum(ERV_LST,na.rm=T))]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",sum(FIDESZ_lst,na.rm=T)]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",(sum(ERV_LST,na.rm=T)/sum(AE,na.rm=T))]
valkor_results_2018_df[TELEPUL=="Hódmezővásárhely",sum(AE,na.rm=T)]


lapply(party_names,function(x) valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(paste0(x,"_lst")))/sum(FE,na.rm=T)])

bp<-valkor_results_2018_df[MEGYE=="BUDAPEST",lapply(.SD, sum, na.rm=T),.SDcols=c('FIDESZ_lst','JOBBIK_lst','MSZP_lst','LMP_lst','DK_lst','MOMENTUM_lst','EGYUTT_lst','MKKP_lst','MAS_lst','ERV_LST')]

bp_pct<-bp/bp[,ERV_LST]

bp_pct<-bp/sum(bp[1,1:6])

valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(FIDESZ_egy,na.rm=T)/sum(FE,na.rm=T))]

valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(ERV_LST,na.rm=T))]
valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(AE,na.rm=T))]
valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(FIDESZ_lst,na.rm=T))]
valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(LMP_lst,na.rm=T))]

valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(FIDESZ_lst,na.rm=T)/sum(ERV_LST,na.rm=T))]
valkor_results_2018_df[MEGYE=="BUDAPEST",sum(FIDESZ_lst,na.rm=T)]
valkor_results_2018_df[MEGYE=="BUDAPEST",(sum(ERV_LST,na.rm=T)/sum(AE,na.rm=T))]
valkor_results_2018_df[MEGYE=="BUDAPEST",sum(AE,na.rm=T)]


##############################individual district results

#getting list of district urls
valker_links<-getlinks_from_t2('http://www.valasztas.hu/dyn/pv18/szavossz/hu/oevker.html')

valker_links<-valker_links[grepl('M',valker_links)]

valker_links<-paste0('http://www.valasztas.hu/dyn/pv18/szavossz/hu/',valker_links)

valker_names<-read_html('http://www.valasztas.hu/dyn/pv18/szavossz/hu/oevker.html')%>%html_table()

#getting voting district results into a list of tables
valker_results<-lapply(valker_links, function(url) read_html(url)%>%html_table())

#getting list of nominating entities, total votes
nominee_table_list<-lapply(valker_results,function(l) l[[5]])

nominee_table<-rbindlist(nominee_table_list)

sum_nominator<-data.frame(nominee_table[,3:4])

sum_nominator[,2]<-as.numeric(gsub('\\s+','',as.character(sum_nominator[,2])))

sum_nominator<-data.table(sum_nominator)

names(sum_nominator)<-c('entity','szavz')

sum_nominator<-sum_nominator[,.(szavz_szam=sum(szavz)),by=entity][order(-szavz_szam)]

View(sum_nominator)

sum(sum_nominator[1:7,2])/sum(sum_nominator[,2])

#scraping district (more aggregated) voring result data
valke_data_names<-c('MEGYE','OEVK','SZEKHELY','AE','BE','CE','EE','FE','IE','JE','JE_pct','KE','ME','ME_pct','NE','ERVTL_LST','ERV_LST',  'FIDESZ_egy','JOBBIK_egy','MSZP_egy','DK_egy','LMP_egy','MOMENTUM_egy','EGYUTT_egy','MKKP_egy','FUGGETLEN_egy','MAS_egy',
                    'FIDESZ_egy_pct','JOBBIK_egy_pct','MSZP_egy_pct','DK_egy_pct','LMP_egy_pct','MOMENTUM_egy_pct','EGYUTT_egy_pct','MKKP_egy_pct','FUGGETLEN_egy_pct','MAS_egy_pct',
                    'FIDESZ_lst','JOBBIK_lst','MSZP_lst','DK_lst','LMP_lst','MOMENTUM_lst','EGYUTT_lst','MKKP_lst','FUGGETLEN_lst','MAS_lst',
                    'FIDESZ_lst_pct','JOBBIK_lst_pct','MSZP_lst_pct','DK_lst_pct','LMP_lst_pct','MOMENTUM_lst_pct','EGYUTT_lst_pct','MKKP_lst_pct','FUGGETLEN_lst_pct','MAS_lst_pct',
                    'FIDESZ_egy_jlt','JOBBIK_egy_jlt','MSZP_egy_jlt','DK_egy_jlt','LMP_egy_jlt','MOMENTUM_egy_jlt','EGYUTT_egy_jlt','MKKP_egy_jlt','FUGGETLEN_egy_jlt','MAS_egy_jlt')
table_list<-valker_results[[1]]

#function to extract voting district data
get_valker_results<-function(table_list) {
  
        #creating a temporary  data.frame for results
        #start with names
        temp_df<-setNames(data.frame(matrix(ncol = length(valke_data_names), nrow = 1)), valke_data_names)
        #table_list<-temp_table
        temp_df[1,4:7]<-as.character(table_list[[2]][2,1:4])
        temp_df[1,8:10]<-as.character(table_list[[3]][2,1:3])
        temp_df[1,c(12:13,15)]<-as.character(table_list[[4]][2,1:3])
        temp_df[,'ME_pct']<-as.character(table_list[[4]][3,2])
        
        temptable<-table_list[[5]]
        names(temptable)<-c('sorszam','nev','szervezet','szav','pct','kepv')
        
        #this is deliberately verbose, to make understanding easier(for loop in previous get restults function may be difficult to read)
        temp_df[,'FIDESZ_egy']<-temptable[temptable$szervezet=='FIDESZ-KDNP','szav']
        temp_df[,'FIDESZ_egy_pct']<-temptable[temptable$szervezet=='FIDESZ-KDNP','pct']
        temp_df[,'FIDESZ_egy_jlt']<-temptable[temptable$szervezet=='FIDESZ-KDNP','nev']
        
        temp_df[,'JOBBIK_egy']<-temptable[temptable$szervezet=='JOBBIK','szav']
        temp_df[,'JOBBIK_egy_pct']<-temptable[temptable$szervezet=='JOBBIK','pct']
        temp_df[,'JOBBIK_egy_jlt']<-temptable[temptable$szervezet=='JOBBIK','nev']
        
        temp_df[,'MSZP_egy']<-temptable[temptable$szervezet=='MSZP-PÁRBESZÉD','szav']
        temp_df[,'MSZP_egy_pct']<-temptable[temptable$szervezet=='MSZP-PÁRBESZÉD','pct']
        temp_df[,'MSZP_egy_jlt']<-temptable[temptable$szervezet=='MSZP-PÁRBESZÉD','nev']

        temp_df[,'DK_egy']<-temptable[temptable$szervezet=='DK','szav']
        temp_df[,'DK_egy_pct']<-temptable[temptable$szervezet=='DK','pct']
        temp_df[,'DK_egy_jlt']<-temptable[temptable$szervezet=='DK','nev']
        
        temp_df[,'LMP_egy']<-temptable[temptable$szervezet=='LMP','szav']
        temp_df[,'LMP_egy_pct']<-temptable[temptable$szervezet=='LMP','pct']
        temp_df[,'LMP_egy_jlt']<-temptable[temptable$szervezet=='LMP','nev']
        
        temp_df[,'MOMENTUM_egy']<-temptable[temptable$szervezet=='MOMENTUM','szav']
        temp_df[,'MOMENTUM_egy_pct']<-temptable[temptable$szervezet=='MOMENTUM','pct']
        temp_df[,'MOMENTUM_egy_jlt']<-temptable[temptable$szervezet=='MOMENTUM','nev']
        
        temp_df[,'EGYUTT_egy']<-temptable[temptable$szervezet=='EGYÜTT','szav']
        temp_df[,'EGYUTT_egy_pct']<-temptable[temptable$szervezet=='EGYÜTT','pct']
        temp_df[,'EGYUTT_egy_jlt']<-temptable[temptable$szervezet=='EGYÜTT','nev']
        
        temp_df[,'MKKP_egy']<-temptable[temptable$szervezet=='MKKP','szav']
        temp_df[,'MKKP_egy_pct']<-temptable[temptable$szervezet=='MKKP','pct']
        temp_df[,'MKKP_egy_jlt']<-temptable[temptable$szervezet=='MKKP','nev']
        
        setDT(temptable)
        temptable[,szav:=lapply(szav,function(x) gsub('[[:space:]]','',as.character(x)))]
        
        #only "significant" independents are counted, with more than 2000 votes
        temp_df[,'FUGGETLEN_egy']<-ifelse ('Független jelölt' %in% temptable[szav>2000,szervezet],temptable[szav>2000,][szervezet=='Független jelölt',szav],NA)
        temp_df[,'FUGGETLEN_egy_pct']<-ifelse ('Független jelölt' %in% temptable[szav>2000,szervezet],temptable[szav>2000,][szervezet=='Független jelölt',pct],NA)
        temp_df[,'FUGGETLEN_egy_jlt']<-ifelse ('Független jelölt' %in% temptable[szav>2000,szervezet],temptable[szav>2000,][szervezet=='Független jelölt',nev],NA)
        
        
        return(temp_df)
}
        
valker_result_tables<-lapply(valker_results,get_valker_results)
valker_result_df <- rbindlist(valker_result_tables)
setDT(valker_result_df)

#adding identifiers at the beginning
valker_result_df[,1:3]<-valker_names[[2]][,1:3]

#tydiing up the datatable

#deleting whitespace+number+%sign combinations from the end of the string
valker_result_df[,c('JE','ME_pct'):=.(sub('[[:space:]][^[:space:]]*\\%$','',JE),sub('[[:space:]][^[:space:]]*\\%$','',ME_pct))]

#deleting first space in JE column
valker_result_df$JE<-sub('\\s+','',valker_result_df$JE)

#splitting JE column to number and percent
valker_result_df[,JE_pct:=data.frame(do.call("rbind", strsplit(sub("\\s+", ";", valker_result_df$JE), ";")))[,2]]
valker_result_df[,JE:=data.frame(do.call("rbind", strsplit(sub("\\s+", ";", valker_result_df$JE), ";")))[,1]]

#deleting all spaces
valker_result_df[,names(valker_result_df[,AE:MAS_lst_pct]):=lapply(.SD,function(x) gsub('[[:space:]]','',as.character(x))),.SDcols=AE:MAS_lst_pct]

#turning everything except names into numeric characters
valker_result_df[,names(valker_result_df[,AE:MAS_lst_pct]):=lapply(.SD,function(x) as.numeric(as.character(x))),.SDcols=AE:MAS_lst_pct]


#calculating "other" votes (not main parties), and their percent share
valker_result_df[,MAS_egy:=NE-rowSums(.SD, na.rm=T),.SDcols=valker_names_egy]
valker_result_df[,MAS_egy_pct:=MAS_egy/NE]

#filling up list result votes aggregated from previous voting place results
setkey(valker_result_df,MEGYE,OEVK)
setkey(listresults_districts,MEGYE,OEVK)

valker_result_df<-valker_result_df[listresults_districts,`:=`(ERVTL_LST=i.ERVTL_LST,ERV_LST=i.ERV_LST,FIDESZ_lst = i.FIDESZ_lst, MSZP_lst=i.MSZP_lst,JOBBIK_lst=i.JOBBIK_lst,LMP_lst=i.LMP_lst,DK_lst=i.DK_lst,MOMENTUM_lst=i.MOMENTUM_lst,EGYUTT_lst=i.EGYUTT_lst,MKKP_lst=i.MKKP_lst,MAS_lst=i.MAS_lst,FIDESZ_lst_pct = i.FIDESZ_lst_pct, MSZP_lst_pct=i.MSZP_lst_pct,JOBBIK_lst_pct=i.JOBBIK_lst_pct,LMP_lst_pct=i.LMP_lst_pct,DK_lst_pct=i.DK_lst_pct,MOMENTUM_lst_pct=i.MOMENTUM_lst_pct,EGYUTT_lst_pct=i.EGYUTT_lst_pct,MKKP_lst_pct=i.MKKP_lst_pct,MAS_lst_pct=i.MAS_lst_pct)]

valker_result_df<-cbind(valker_result_df,winner=colnames(valker_result_df[,FIDESZ_egy:MAS_egy])[apply(valker_result_df[,FIDESZ_egy:MAS_egy],1,which.max)])

#calculating ratios
valker_result_df[,FE_pct:=FE/AE]
valker_result_df[,names(valker_result_df[,FIDESZ_egy_pct:MAS_egy_pct]):=lapply(.SD,function(x) x/NE),.SDcols=(FIDESZ_egy:MAS_egy)]
#valker_result_df[,names(valkor_results_df[,FIDESZ_lst_pct:MAS_lst_pct]):=lapply(.SD,function(x) x/ERV_LST),.SDcols=(FIDESZ_lst:MAS_lst)]

#aggreagting liberal/left opposition votes
valker_result_df[,LEFTLIB_OPP_lst_pct:=(MSZP_lst_pct+LMP_lst_pct+DK_lst_pct+MOMENTUM_lst_pct+EGYUTT_lst_pct)]
valker_result_df[,LEFTLIB_OPP_egy_pct:=rowSums(.SD, na.rm=T),.SDcols=valker_names_egy_pct[3:7]]

valker_result_df[,LEFTLIB_OPP_lst:=(MSZP_lst+LMP_lst+DK_lst+MOMENTUM_lst+EGYUTT_lst)]
valker_result_df[,LEFTLIB_OPP_egy:=rowSums(.SD, na.rm=T),.SDcols=valker_names_egy[3:7]]


#calculating difference between individual and list vote percents (positive=individual larger)
valker_result_df[,FIDESZ_dev_lst_egy:=FIDESZ_egy_pct-FIDESZ_lst_pct]
valker_result_df[,JOBBIK_dev_lst_egy:=JOBBIK_egy_pct-JOBBIK_lst_pct]
valker_result_df[,LEFTLIB_OPP_dev_lst_egy:=LEFTLIB_OPP_egy_pct-LEFTLIB_OPP_lst_pct]

#optional
valker_result_df[,MSZP_DK_dev_lst_egy:=(MSZP_egy_pct+DK_egy_pct)-(MSZP_lst_pct+DK_lst_pct)]
valker_result_df[,LMP_dev_lst_egy:=LMP_egy_pct-LMP_lst_pct]
valker_result_df[,EGYUTT_dev_lst_egy:=EGYUTT_egy_pct-EGYUTT_lst_pct]
valker_result_df[,MOMENTUM_dev_lst_egy:=MOMENTUM_egy_pct-MOMENTUM_lst_pct]
valker_result_df[,MKKP_dev_lst_egy:=MKKP_egy_pct-MKKP_lst_pct]

valker_result_df[,FIDESZ_dev_lst_egy_vts:=FIDESZ_egy-FIDESZ_lst]
valker_result_df[,JOBBIK_dev_lst_egy_vts:=JOBBIK_egy-JOBBIK_lst]
valker_result_df[,LEFTLIB_OPP_dev_lst_egy_vts:=LEFTLIB_OPP_egy-LEFTLIB_OPP_lst]

#optional
valker_result_df[,MSZP_DK_dev_lst_egy_vts:=(MSZP_egy+DK_egy)-(MSZP_lst+DK_lst)]
valker_result_df[,LMP_dev_lst_egy_vts:=LMP_egy-LMP_lst]
valker_result_df[,EGYUTT_dev_lst_egy_vts:=EGYUTT_egy-EGYUTT_lst]
valker_result_df[,MOMENTUM_dev_lst_egy_vts:=MOMENTUM_egy-MOMENTUM_lst]
valker_result_df[,MKKP_dev_lst_egy_vts:=MKKP_egy-MKKP_lst]

data.frame(table(valker_result_df$winner))

valker_result_df_2018<-valker_result_df

##################saving valker results
write.csv(valker_result_df,'valker_results_final_2018.csv')
tt<-read.csv('valker_results_final_2018.csv')
setDT(tt)

##################END


####################################################APPENDIX
#this part was just used for cross-check variable name
#function to get variable names in tables
get_val_kor_varlist<-function(full_table_list) {
        df <- read.csv(text="",col.names = valkor_data_names, colClasses = 'character')
        temp_df<-setNames(data.frame(matrix(ncol = length(valkor_data_names), nrow = 1)), valkor_data_names)
        temp_df[]<-lapply(temp_df, function(x) as.character(x))
        setDT(temp_df)
        
        for (k in 1:length(full_table_list)) {indiv_valkor_tables_list<-full_table_list[[k]]
        print(paste0("k=",k))      
        
        for (i in 2:5) {
                temp_table<-indiv_valkor_tables_list[[i]]        
                for (j in 1:length (temp_table[1,])){
                        if (!temp_table[1,j]%in%names(temp_df)&nchar(temp_table[1,j])==2) {temp_df<-(cbind(temp_df,setNames(data.frame(c= k), as.character(temp_table[1,j]))))}
                        #ifelse (temp_table[1,j]%in%names(temp_df),print(temp_table[1,j]),temp_df<-(cbind(temp_df,setNames(data.frame(c= NA), as.character(temp_table[1,j])))))
                        #}
                }
        }
        
        }
        return(temp_df)
}        

varnames<-get_val_kor_varlist(valkor_results_final)

