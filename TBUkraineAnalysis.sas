/* ----------------------------------------------------------------------------------- */
/* TB IN UKRAINE */
/* Skills: Data Cleaning, Visualization, Correlation, Logistic Regression, Reporting */
/* ----------------------------------------------------------------------------------- */

options errors=1000;

libname TBUKData "/home/u63753154/New Individual work";

/* ---------------------------------- */
/* 1. Import Dataset                  */
/* ---------------------------------- */
proc import datafile="/home/u63753154/New Individual work/ukr_adults_ILE.csv"
    dbms=csv 
    out=TBUKData.UKTBAdults1
    replace;
    getnames=yes;
    guessingrows=max;
run;

proc contents data=TBUKData.UKTBAdults1; run;

/* Rename long/awkward variable for ease */
data TBUKData.UKTBAdults2;
    set TBUKData.UKTBAdults1;
    rename 'DST.result.r'n = dst_result_r;
run;

proc freq data=TBUKData.UKTBAdults2;
    tables dst_result_r Age Sex hiv_def / missing;
run;


/* ---------------------------------- */
/* 2. VISUALIZATION - HEAT MAP BASED ON CORRELATION BETWEEN VARIABLES */
/* ---------------------------------- */

/* Step 1: Create numeric versions of categorical variables for correlation analysis AND a new variable 'social_score'*/
data TBUKData.UKTB_clean;
    set TBUKData.UKTBAdults2;

    /* Use actual column names from PROC CONTENTS */
     if STRIP(final_outcome_group) = "Cure or Treatment Completion" then final_outcome_group_num = 0;
    else if  STRIP(final_outcome_group) = "Failure" then final_outcome_group_num = 1;
    else if  STRIP(final_outcome_group) = "Death or Palliative Care" then final_outcome_group_num = 2;
    else if  STRIP(final_outcome_group) = "Transfer" then final_outcome_group_num = 3;
    else if  STRIP(final_outcome_group) = "Treatment discontinuation" then final_outcome_group_num = 3;
    else if  STRIP(final_outcome_group) = "Treatment in process" then final_outcome_group_num = 5;
    else  final_outcome_group_num = 6; 
    
    /*NOTE: STRIP(...) removes any extra spaces from the beginning and end of the string.
	Prevents errors if values are accidentally recorded as " Cure or Treatment Completion " (with spaces).*/

    IF STRIP(dst_result_r) = "Resistant" THEN dst_result_r_num = 1;
    ELSE IF STRIP(dst_result_r) = "Sensitive" THEN dst_result_r_num = 0;
    ELSE IF STRIP(dst_result_r) = "Contaminated" THEN dst_result_r_num = 2;
    ELSE dst_result_r_num = 3;

    IF STRIP(hiv_def) = "Positive" THEN hiv_def_num = 1;
    ELSE IF STRIP(hiv_def) = "Negative" THEN hiv_def_num = 0;
    ELSE IF STRIP(hiv_def) = "Unknown" THEN hiv_def_num = 2;
    ELSE IF STRIP(hiv_def) = "NA" THEN hiv_def_num = 3;
	ELSE hiv_def_num = 4;

    IF STRIP(sex) = "Male" THEN sex_num = 1;
    ELSE IF STRIP(sex) = "Female" THEN sex_num = 0;
    ELSE sex_num = 2;
    
      if STRIP(Age >= 20 and Age <= 40) then age_num = 0;
    else if STRIP(Age >= 41 and Age <= 60) then age_num = 1;
    else if STRIP(Age >60) then age_num = 2;
    else age_num = 3;
    
         /* Create Social Vulnerability Score */
    social_score = 0;
    if strip(Homeless) = "Yes" then social_score + 1;
    if strip(Unemployed) = "Yes" then social_score + 1;
    if strip(Alcohol_abuse) = "Yes" then social_score + 1;
    if strip(Injecting_drug_use) = "Yes" then social_score + 1;
    if strip(Prisoner) = "Yes" then social_score + 1;
    if strip(Healthcare_worker) = "Yes" then social_score + 1;
    if strip(migrant_refugee) = "Yes" then social_score + 1;

    KEEP age_num sex_num dst_result_r_num hiv_def_num final_outcome_group_num social_score; /*Only keep these five variables in the new dataset. 
    All other variables from the original dataset will not be included*/
RUN;

/* Step 2: Generate a correlation matrix between the recoded numeric variables */
PROC CORR DATA=TBUKData.UKTB_clean OUTP=work.corr_matrix NOPRINT;
    VAR age_num sex_num dst_result_r_num hiv_def_num final_outcome_group_num;
RUN;

/* Step 3: Reshape correlation matrix into long format for plotting */
DATA work.corr_long;
    SET work.corr_matrix;
    ARRAY vars {*} age_num sex_num dst_result_r_num hiv_def_num final_outcome_group_num; /* Used to loop through all the numeric variables*/
    DO i = 1 TO DIM(vars);
        x_name = _NAME_;			/* The variable from the row (e.g., age_num) */
        y_name = VNAME(vars[i]);	/* The variable from the column (e.g., sex_num) */
        corr_value = vars[i];		/* The correlation value between the row and column */
        OUTPUT;						/* Save this row to the new dataset */
    END;
    KEEP x_name y_name corr_value;  /*ensures only the 3 columns (x_name, y_name, and corr_value) are stored*/
RUN;

/* Step 4: Filter out irrelevant rows — keep only variable pairs of interest */
DATA work.corr_long_clean;
    SET work.corr_long;
    IF x_name IN ("age_num", "sex_num", "dst_result_r_num", "hiv_def_num", "final_outcome_group_num") AND
       y_name IN ("age_num", "sex_num", "dst_result_r_num", "hiv_def_num", "final_outcome_group_num");
RUN;

/* Step 5: Assign numeric IDs to variables for easier axis placement in heatmap */
DATA work.corr_for_plot;
    SET work.corr_long_clean;
    LENGTH x_id y_id 8;

    SELECT (x_name);
        WHEN ("age_num")                        x_id = 1;
        WHEN ("sex_num")                   x_id = 2;
        WHEN ("dst_result_r_num")         x_id = 3;
        WHEN ("hiv_def_num")              x_id = 4;
        WHEN ("final_outcome_group_num")  x_id = 5;
        OTHERWISE x_id = .;
    END;

    SELECT (y_name);
        WHEN ("age_num")                        y_id = 1;
        WHEN ("sex_num")                   y_id = 2;
        WHEN ("dst_result_r_num")         y_id = 3;
        WHEN ("hiv_def_num")              y_id = 4;
        WHEN ("final_outcome_group_num")  y_id = 5;
        OTHERWISE y_id = .;
    END;
RUN;

/* Step 6: Assign friendly labels for the heatmap */
PROC FORMAT;
    VALUE varfmt
        1 = "age_num"
        2 = "sex_num"
        3 = "dst_result_r_num"
        4 = "hiv_def_num"
        5 = "final_outcome_group_num";
RUN;

/* Step 7: Plot heatmap */
/*	First create character labels for axes */
DATA work.corr_for_plot_final;
    SET work.corr_for_plot;

    /* Create labels manually based on numeric IDs */
    LENGTH char_x $30 char_y $30;

    IF x_id = 1 THEN char_x = "age";
    ELSE IF x_id = 2 THEN char_x = "sex";
    ELSE IF x_id = 3 THEN char_x = "Rifampin DST result";
    ELSE IF x_id = 4 THEN char_x = "HIV";
    ELSE IF x_id = 5 THEN char_x = "Final Outcome";

    IF y_id = 1 THEN char_y = "age";
    ELSE IF y_id = 2 THEN char_y = "sex";
    ELSE IF y_id = 3 THEN char_y = "Rifampin DST result";
    ELSE IF y_id = 4 THEN char_y = "HIV";
    ELSE IF y_id = 5 THEN char_y = "Final Outcome";
RUN;
/*Now plot the axes to create the heatmap*/
PROC SGPLOT DATA=work.corr_for_plot_final;
    HEATMAPPARM X=char_x Y=char_y COLORRESPONSE=corr_value / colormodel=(darkblue lavender white pink red);
    XAXIS DISCRETEORDER=DATA DISPLAY=(nolabel);
    YAXIS DISCRETEORDER=DATA DISPLAY=(nolabel);
    TITLE "Correlation Heatmap of characteristics";
RUN;

/* ---------------------------------- */
/* 3. Descriptive Statistics for Social Vulnerability Score*/
/* ---------------------------------- */
proc freq data=TBUKData.UKTB_clean;
    tables social_score / missing;
    title "Frequency Distribution of Social Vulnerability Score";
run;

proc means data=TBUKData.UKTB_clean n mean std min max;
    var social_score;
    title "Descriptive Statistics for Social Vulnerability Score";
run;

/* ---------------------------------- */
/* 5. Logistic Regression             */
/* ---------------------------------- */
proc logistic data=TBUKData.UKTB_clean;
    class sex_num(ref='1') dst_result_r_num(ref='0') hiv_def_num(ref='0') / param=ref;
    model final_outcome_group_num(event='1') = sex_num age dst_result_r_num hiv_def_num;
    title "Logistic Regression: Predicting TB Treatment Failure";
run;

/* 5b. Stratified Analysis of RR-TB by Sex */
/* Purpose: Evaluate how RR-TB affects treatment outcome separately for men and women */
/* ---------------------------------- */

proc logistic data=TBUKData.UKTB_clean;
    where sex = "Male";
    class dst_result_r_num(ref='0') / param=ref;
    model final_outcome_group_num(event='1') = dst_result_r_num;
    title "Effect of RR-TB on Treatment Failure Among Males";
run;

proc logistic data=TBUKData.UKTB_clean;
    where sex = "Female";
    class dst_result_r_num(ref='0') / param=ref;
    model final_outcome_group_num(event='1') = dst_result_r_num;
    title "Effect of RR-TB on Treatment Failure Among Females";
run;

/* ----------------------------------------------------------------------------------- */
/* TABLE 1: Baseline Characteristics by Treatment Outcome - Not excluding Fake Failures */
/* ----------------------------------------------------------------------------------- */
/* Recode 'DST.result.R','final_outcome_group', 'Sex', 'Age', 'hiv_def' based on specified conditions */
data UKTBAdults2_recodedDSTR;
    set TBUKData.UKTBAdults2;  
    if DST.result.R = 'Resistant' then Recoded_DST_result_R = 1;
    else if DST.result.R = 'Sensitive' then Recoded_DST_result_R = 0;
    else if DST.result.R = 'NA' then Recoded_DST_result_R = 2; /* Adding condition to recode 'N/A' to 2 */
    else if DST.result.R = 'Contaminated' then Recoded_DST_result_R = 3; /* Adding condition to recode 'N/A' to 2 */
    else Recoded_DST_result_R = .; /* Assign missing value if none of the above conditions are met */

if final_outcome_group = 'Cure or Treatment Completion' then Recoded_final_outcome_group = 0;
    else if final_outcome_group = 'Failure' then Recoded_final_outcome_group = 1;
    else if final_outcome_group = 'Transfer' then Recoded_final_outcome_group = 2; 
    else if final_outcome_group = 'Death or Palliative Care' then Recoded_final_outcome_group = 3; 
    else if final_outcome_group = 'Treatment discontinuation' then Recoded_final_outcome_group = 4;
    else if final_outcome_group = 'Treatment in process' then Recoded_final_outcome_group = 5;
    else Recoded_final_outcome_group = 6; /* Assign missing value if none of the above conditions are met */
run;

proc freq data=UKTBAdults2_recodedDSTR;
    tables Recoded_DST_result_R;
run;

/*renaming 'fake failure' to 'fake_failure'*/
data UKTBAdults2_recodedDSTR1;
set UKTBAdults2_recodedDSTR;
rename 'fake failure'n=fake_failure;
run;

data UKTBAdults2_recodedDSTR12;
    set UKTBAdults2_recodedDSTR1;
    if Age >= 20 and Age <= 40 then Age_Group = '0';
    else if Age >= 41 and Age <= 60 then Age_Group = '1';
    else if Age > 60 then Age_Group = '2';
    
    if Sex='Male' then Sex_New='1';
    else if Sex='Female' then Sex_New='0';
    
    if hiv_def = 'Positive' then HIV_def_num = 1;
    else if hiv_def = 'Negative' then HIV_def_num = 0;
    else if hiv_def = 'Unknown' then HIV_def_num = 2;
    else if hiv_def = 'NA' then HIV_def_num = 3;
   
       where Recoded_final_outcome_group in (0,1);   /*Only include Treatment failure and treatment success*/

run;


/*Baseline Characteristic: Rifampin Resistance Status (DST) by Final outcome*/
proc freq data=UKTBAdults2_recodedDSTR12;
 where Recoded_DST_result_R in (0, 1); /* Exclude NA and Contaminated */
    tables Recoded_DST_result_R * Recoded_final_outcome_group / chisq out=FreqTable;
    title "Baseline Characteristic: Rifampin Resistance Status (DST) by Final outcome";
run;

/*Baseline Characteristic: Age Categories by Final outcome*/
proc freq data=UKTBAdults2_recodedDSTR12;
    tables Age_Group * Recoded_final_outcome_group / chisq out=FreqTable;
    title "Baseline Characteristic: Age Categories by Final outcome";
run;

/* Baseline Characteristic: Sex by Final outcome */
proc freq data=UKTBAdults2_recodedDSTR12;
    tables Sex_New * Recoded_final_outcome_group / chisq out=FreqTable;
    title "Baseline Characteristic: Sex by Final outcome";
run;

/* Baseline Characteristic: HIV Status by Final Outcome */
proc freq data=UKTBAdults2_recodedDSTR12;
where HIV_def_num in (0,1);
    tables HIV_def_num * Recoded_final_outcome_group  / chisq out=FreqTable;
    title "Baseline Characteristic: HIV Status by Final Outcome";
run;


/* ----------------------------------------------------------------------------------- */
/* TABLE 2: Adjusted Odds Ratios – Logistic Regression */
/* ----------------------------------------------------------------------------------- */


/*Logistic regression with Age_group ref = >60 years*/
proc logistic data=UKTBAdults2_recodedDSTR12;
 where Recoded_DST_result_R in (0, 1) and HIV_def_num in (0,1); /* Exclude NA and Contaminated */
    class Recoded_DST_result_R (ref='0') 
          Age_Group 
          Sex_New 
          HIV_def_num (ref='0') / param=ref;  /* Set HIV Positive as reference */
    model Recoded_final_outcome_group (event='1') = Recoded_DST_result_R Age_Group Sex_New HIV_def_num;
    /*oddsratio Recoded_DST_result_R / cl=wald;*/
   /* Test line*/
    ods output OddsRatios=OR_ResistantvsSensitive;
run;

/*TABLE*/

data OR_Res_Sens;
    set OR_ResistantvsSensitive;
    Comparison = "Resistant vs Sensitive";
run;

data OR_AllComparisons;
    set OR_ResistantvsSensitive;
run;
title "Odds Ratios by DST Comparison";
proc print data=OR_AllComparisons noobs label;
run;


/*Logistic regression with Age_group ref = 20-40 years*/
proc logistic data= UKAdults1_recodedDSTR12;
WHERE Recoded_DST_result_R in (0,1) and HIV_def_num in (0,1); 
class Recoded_DST_result_R (ref='0')
Age_Group (ref='1')
Sex_New 
          HIV_def_num (ref='0') / param=ref;  /* Set HIV Positive as reference */
    model Recoded_final_outcome_group (event='1') = Recoded_DST_result_R Age_Group Sex_New HIV_def_num;
    oddsratio Recoded_DST_result_R / cl=wald;
    ods output OddsRatios=OR_newResistantvsSensitive;
run;


data OR_newRes_Sens;
    set OR_newResistantvsSensitive;
    Comparison = "Resistant vs Sensitive";
run;

data OR_newAllComparisons;
    set OR_newResistantvsSensitive;
run;
title "Odds Ratios by DST Comparison";
proc print data=OR_newAllComparisons noobs label;
run;


/* ----------------------------------------------------------------------------------- */
/* Bar chart */
/* ----------------------------------------------------------------------------------- */

proc freq data=UKAdults1_recodedDSTR12 noprint;
    where Recoded_DST_result_R in (0, 1);
    tables Recoded_DST_result_R * Recoded_final_outcome_group / out=RawCounts;
run;
proc sort data=RawCounts;
    by Recoded_DST_result_R;
run;

data PercentData;
    set RawCounts;
    by Recoded_DST_result_R;

    retain Total;
    if first.Recoded_DST_result_R then Total = 0;
    Total + COUNT;

    if last.Recoded_DST_result_R then do;
        call symputx('Total_' || strip(Recoded_DST_result_R), Total);
    end;
run;

data BarChart_Percent;
    set RawCounts;

    /* Assign totals from macro variables */
    if Recoded_DST_result_R = 0 then Total = symgetn('Total_0');
    else if Recoded_DST_result_R = 1 then Total = symgetn('Total_1');

    Percent = 100 * COUNT / Total;

    /* Label variables */
    length DST_Label $15 Outcome_Label $20;

    if Recoded_DST_result_R = 0 then DST_Label = "Sensitive";
    else if Recoded_DST_result_R = 1 then DST_Label = "Resistant";

    if Recoded_final_outcome_group = 0 then Outcome_Label = "Success";
    else if Recoded_final_outcome_group = 1 then Outcome_Label = "Failure";
run;
proc sgplot data=BarChart_Percent;
    hbar DST_Label / response=Percent group=Outcome_Label 
        groupdisplay=stack datalabel dataskin=pressed;

    xaxis label="Percentage";
    yaxis label="Rifampin DST Result";
    title "Treatment Outcomes by Rifampin Resistance Status (% within group)";
run; 

/* ---------------------------------- */
/* 6. Save Outputs for Reproducibility*/
/* ---------------------------------- */
proc export data=TBUKData.UKTB_clean
    outfile="/home/u63753154/New Individual work/cleaned_output.csv"
    dbms=csv
    replace;
run;













/* ---------------------------------- */
/* Bivariate Association Tests     */
/* Purpose: To identify variables significantly associated with HIV status for inclusion in multivariate modeling */
/* ---------------------------------- */

proc contents data=TBUKData.UKTBAdults1; run;

/* Rename long/awkward variable for ease */
data TBUKData.UKTBAdults2;
    set TBUKData.UKTBAdults1;
    rename 'DST.result.r'n = DSTresultR;
run;

proc freq data=TBUKData.UKTBAdults2;
    tables final_outcome_group / missing;
run;

/* ---------------------------------- */
/* 2. Data Cleaning & Deduplication   */
/* ---------------------------------- */
proc sort data=TBUKData.UKTBAdults2 out=TBUKData.sorted_data;
    by case_id;
run;

data TBUKData.tb_clean;
    set TBUKData.sorted_data;
    by case_id;
    if first.case_id; /* Keep only the first row for each case */

    /* Apply Inclusion/Exclusion Criteria */
    if HIV_def in ('Missing', 'Unknown') then delete;
    if final_outcome_group in ('Treatment in process', 'Transfer') then delete;
    if fake_failure = 1 then delete;
run;

/* ---------------------------------- */
/* 3. Chi-Square Tests                */
/* ---------------------------------- */
proc freq data=TBUKData.tb_clean;
    tables HIV_def*(Sex new_prev Homeless Unemployed Cavitation DSTresultR) / chisq;
run;

/* ---------------------------------- */
/* 4. T-Test for Age by HIV Status    */
/* ---------------------------------- */
proc ttest data=TBUKData.tb_clean;
    class HIV_def;
    var Age;
run;

/* ---------------------------------- */
/* 5. Logistic Regression             */
/* ---------------------------------- */
proc logistic data=TBUKData.tb_clean;
    class HIV_def (ref="Positive")
          Sex (ref="Male")
          Homeless (ref="Yes")
          new_prev (ref="Previously treated")
          Unemployed (ref="Yes")
          DSTresultR (ref="Resistant")
          Cavitation (ref="Yes") / param=ref;
    model final_outcome_group(event="Cure or Treatment Completion") = 
          HIV_def Age Sex new_prev Homeless Unemployed DSTresultR Cavitation;
run;

/* ---------------------------------- */
/* 6. Save Outputs for Reproducibility*/
/* ---------------------------------- */
proc export data=TBUKData.tb_clean
    outfile="/home/u63753154/New Individual work/final_tb_cleaned.csv"
    dbms=csv
    replace;
run;

/* End of enhanced clinical analytics with modeling and rigorous data prep */





