/*==========================================================*/
/* Income Shifting Determinants - Research Project             */
/*==========================================================*/
/* This script builds a dataset of multinational firms and    */
/* tests whether tax rate differentials between domestic and  */
/* foreign jurisdictions drive income shifting behavior.      */
/* Data sources: Compustat Fundamentals + Compustat Segments  */
/* Analysis period: 2010-2024, excluding 2017 (TCJA year).   */
/*==========================================================*/

/* Permanent library for saving all datasets */
libname isdata "~/inc_shift";


/*----------------------------------------------------------*/
/* Macro Variable Block                                      */
/*----------------------------------------------------------*/
/* Define analysis window, tax parameters, and variable      */
/* caps up front so every downstream step references these   */
/* consistently. Change once here, flows everywhere.         */
/*----------------------------------------------------------*/

/* Analysis period: 2017 skipped as TCJA transition year */
%let beg_yr   = 2010;
%let end_yr   = 2024;
%let skip_yr  = 2017;

/* TCJA parameters */
%let tcja_yr     = 2018;       /* First post-TCJA fiscal year           */
%let usr_pre     = 0.35;       /* U.S. statutory rate pre-TCJA          */
%let usr_post    = 0.21;       /* U.S. statutory rate post-TCJA         */

/* Variable capping thresholds (symmetric around zero)       */
/* Applied to income_shift, tax_diff, and ww_profit          */
%let cap_upper =  1;
%let cap_lower = -1;

/* Sensitivity flag: domestic classification currently uses   */
/* a BROAD definition â€” "North America", "Americas",         */
/* "The Americas", and "Corporate" are all coded as domestic. */
/* For robustness, re-run with these excluded entirely        */
/* (drop from dataset before aggregation) so ambiguous        */
/* segments don't contaminate either side.                    */

/* Additional note: "CORPORATE AND OTHER" (171 obs) is       */
/* classified as foreign because it doesn't exact-match the   */
/* domestic keyword list, while plain "CORPORATE" (461 obs)   */
/* is classified as domestic. Review in sensitivity analysis.  */



/*==========================================================*/
/* Step 1: Extract Compustat Fundamentals Annual Data         */
/*==========================================================*/
/* Pull firm-year financials for multinational firms that     */
/* report in USD and have positive domestic income (pidom),   */
/* foreign income (pifo), total assets, sales, and PP&E.     */
/* COALESCE replaces missing values with 0 for variables     */
/* where missing likely means the firm had none (debt, R&D,  */
/* advertising, taxes). Standard academic filters applied.   */
/*==========================================================*/
proc sql;
    create table is_raw as
    select 
        gvkey,
        datadate,
        fyear,
        conm as company_name,
        sich,
        at,
        pidom,
        pifo,
        sale,
        coalesce(dltt, 0) as dltt,
        coalesce(dlc, 0) as dlc,
        coalesce(xrd, 0) as xrd,
        coalesce(xad, 0) as xad,
        ppent,
        coalesce(txt, 0) as txt,
        coalesce(txfo, 0) as txfo
    from comp.funda
    where indfmt='INDL' 
        and datafmt='STD' 
        and consol='C' 
        and popsrc='D'
        and curcd='USD'
        and fyear between &beg_yr and &end_yr
        and fyear not in (&skip_yr)
        and at > 0
        and pidom > 0
        and pifo > 0
        and sale > 0
        and ppent > 0
        and txt >= 0
        and txfo >= 0
    order by gvkey, fyear;
quit;


/*----------------------------------------------------------*/
/* Step 1 Quality Checks                                     */
/*----------------------------------------------------------*/

/* QC1: Confirm which fiscal years are present and that      */
/* skip_yr (2017) is excluded                                */
proc sql;
    select fyear, count(*) as n_obs
    from is_raw
    group by fyear
    order by fyear;
    title 'QC1: Observation Count by Fiscal Year';
quit;


/* QC2: Check for duplicate firm-years (should return 0)     */
proc sql;
    select count(*) as n_duplicates
    from (
        select gvkey, fyear, count(*) as cnt
        from is_raw
        group by gvkey, fyear
        having cnt > 1
    );
    title 'QC2: Duplicate Firm-Years (should be 0)';
quit;


/* QC3: Sample composition â€” total obs, unique firms, range  */
proc sql;
    select 
        count(*) as total_obs,
        count(distinct gvkey) as unique_firms,
        min(fyear) as first_year,
        max(fyear) as last_year
    from is_raw;
    title 'QC3: Sample Composition';
quit;


/* QC4: Summary statistics to verify filters worked â€”        */
/* all minimums should be positive per our WHERE clause      */
proc means data=is_raw n nmiss mean median min max;
    var at pidom pifo sale ppent dltt dlc xrd xad txt txfo;
    title 'QC4: Summary Statistics â€” Verify All Filters Held';
run;



/*==========================================================*/
/* Step 2: Extract Geographic Segments Data                   */
/*==========================================================*/
/* Pull geographic segments (stype='GEOSEG') with non-       */
/* negative sales and assets. Then deduplicate: when a        */
/* segment has multiple source dates for the same datadate,   */
/* keep only the most recent filing (latest srcdate).         */
/*==========================================================*/
proc sql;
    create table is_geo_raw as
    select 
        gvkey,
        datadate,
        srcdate,
        year(datadate) as fyear,
        stype,
        sid,
        snms,
        geotp,
        sales,
        ias
    from compseg.wrds_segmerged
    where stype = 'GEOSEG'
        and year(datadate) between &beg_yr and &end_yr
        and year(datadate) not in (&skip_yr)
        and sales >= 0
        and ias >= 0        
    order by gvkey, fyear, sid;
quit;

/*----------------------------------------------------------*/
/* Deduplicate: keep latest srcdate per gvkey-datadate-sid   */
/* Step A: sort so latest srcdate is first within each group */
/* Step B: nodupkey keeps only the first (latest) record     */
/*----------------------------------------------------------*/
proc sort data=is_geo_raw out=is_geo_sort1;
    by gvkey datadate sid descending srcdate;
run;

proc sort data=is_geo_sort1 out=is_geo nodupkey;
    by gvkey datadate sid;
run;


/*----------------------------------------------------------*/
/* Step 2 Quality Checks                                     */
/*----------------------------------------------------------*/

/* QC1: Confirm fiscal years present and skip_yr excluded    */
proc sql;
    select fyear, count(*) as n_obs
    from is_geo
    group by fyear
    order by fyear;
    title 'Geo QC1: Observation Count by Fiscal Year';
quit;


/* QC2: Check for remaining duplicates at gvkey-datadate-sid */
/* (should be 0 after dedup)                                 */
proc sql;
    select count(*) as n_duplicates
    from (
        select gvkey, datadate, sid, count(*) as cnt
        from is_geo
        group by gvkey, datadate, sid
        having cnt > 1
    );
    title 'Geo QC2: Remaining Duplicates (should be 0)';
quit;


/* QC3: Sample composition                                   */
proc sql;
    select 
        count(*) as total_obs,
        count(distinct gvkey) as firms_with_segments,
        min(fyear) as first_year,
        max(fyear) as last_year
    from is_geo;
    title 'Geo QC3: Sample Composition';
quit;


/* QC4: Summary stats on sales and ias â€” minimums should     */
/* be >= 0 per our WHERE clause                              */
proc means data=is_geo n nmiss mean median min max;
    var sales ias;
    title 'Geo QC4: Summary Statistics â€” Sales and Assets';
run;


/* QC5: Top 50 most frequent segment names â€” useful for      */
/* reviewing before the domestic/foreign classification step  */
proc freq data=is_geo order=freq;
    tables snms / nocum maxlevels=50;
    title 'Geo QC5: Top 50 Segment Names';
    where snms is not missing;
run;



/*==========================================================*/
/* Step 3: Classify Segments as Domestic vs Foreign           */
/*==========================================================*/
/* Uppercase segment names for consistent matching. Domestic  */
/* = broad definition: explicit U.S. labels, all 50 states,  */
/* plus "North America", "Americas", "The Americas", and     */
/* "Corporate" (see sensitivity note in macro block).         */
/* Everything else defaults to foreign.                       */
/*==========================================================*/
data is_geo2;
    set is_geo;

    /* Standardize segment name for matching */
    snms_upper = upcase(snms);

    /* Default to foreign */
    domestic = 0;

    /* Broad U.S. / domestic labels */
    if snms_upper in (
        'UNITED STATES OF AMERICA',
        'UNITED STATES',
        'U.S.',
        'US',
        'USA',
        'U S',
        'U.S.A.',
        'AMERICA',
        'CORPORATE',
        'DOMESTIC',
        'NORTH AMERICA',
        'AMERICAS',
        'THE AMERICAS'
    ) then domestic = 1;

    /* U.S. state names */
    else if snms_upper in (
        'ALABAMA','ALASKA','ARIZONA','ARKANSAS','CALIFORNIA',
        'COLORADO','CONNECTICUT','DELAWARE','FLORIDA','GEORGIA',
        'HAWAII','IDAHO','ILLINOIS','INDIANA','IOWA','KANSAS',
        'KENTUCKY','LOUISIANA','MAINE','MARYLAND','MASSACHUSETTS',
        'MICHIGAN','MINNESOTA','MISSISSIPPI','MISSOURI','MONTANA',
        'NEBRASKA','NEVADA','NEW HAMPSHIRE','NEW JERSEY','NEW MEXICO',
        'NEW YORK','NORTH CAROLINA','NORTH DAKOTA','OHIO','OKLAHOMA',
        'OREGON','PENNSYLVANIA','RHODE ISLAND','SOUTH CAROLINA',
        'SOUTH DAKOTA','TENNESSEE','TEXAS','UTAH','VERMONT',
        'VIRGINIA','WASHINGTON','WEST VIRGINIA','WISCONSIN','WYOMING'
    ) then domestic = 1;

    foreign = 1 - domestic;
run;


/*----------------------------------------------------------*/
/* Step 3 Quality Checks                                     */
/*----------------------------------------------------------*/

/* QC1: Overall domestic vs foreign split                    */
proc freq data=is_geo2;
    tables domestic / nocum;
    title 'Classification QC1: Domestic vs Foreign Split';
run;


/* QC2: Verify borderline labels classified as domestic      */
proc freq data=is_geo2 order=freq;
    tables snms_upper / nocum nopercent list;
    title 'Classification QC2: Domestic Segment Names';
    where domestic = 1;
run;


/* QC3: Top 30 foreign segment names â€” spot-check that       */
/* nothing obviously U.S. slipped through as foreign          */
proc freq data=is_geo2 order=freq;
    tables snms_upper / nocum maxlevels=30;
    title 'Classification QC3: Top 30 Foreign Segment Names';
    where foreign = 1;
run;



/*==========================================================*/
/* Step 4: Aggregate Segments to Firm-Year Level              */
/*==========================================================*/
/* Sum sales and assets by domestic/foreign for each firm-    */
/* year. HAVING clause restricts to firms with BOTH domestic  */
/* and foreign operations â€” required for income shifting      */
/* analysis since the DV is the difference in profit margins. */
/*==========================================================*/
proc sql;
    create table is_geo_agg as
    select 
        gvkey,
        fyear,
        sum(ias * foreign) as foreign_assets, 
        sum(ias * domestic) as domestic_assets,
        sum(sales * foreign) as foreign_sales,
        sum(sales * domestic) as domestic_sales,
        count(*) as num_segments,
        sum(foreign) as num_foreign_segs,
        sum(domestic) as num_domestic_segs
    from is_geo2
    group by gvkey, fyear
    having foreign_assets > 0 and domestic_assets > 0;
quit;


/*----------------------------------------------------------*/
/* Step 4 Quality Checks                                     */
/*----------------------------------------------------------*/

/* QC1: Sample composition                                   */
proc sql;
    select 
        count(*) as n_firmyears,
        count(distinct gvkey) as n_firms,
        min(fyear) as first_year,
        max(fyear) as last_year
    from is_geo_agg;
    title 'Agg QC1: Firm-Years with Both Foreign and Domestic';
quit;


/* QC2: All values should be strictly positive after HAVING  */
proc means data=is_geo_agg n nmiss mean median min max;
    var foreign_assets domestic_assets foreign_sales domestic_sales
        num_segments num_foreign_segs num_domestic_segs;
    title 'Agg QC2: Summary Stats â€” All Should Be > 0';
run;


/* QC3: How many firm-years did we lose from the HAVING      */
/* clause? Compare total firm-years before vs after.         */
proc sql;
    select 
        count(distinct catx('-', gvkey, fyear)) as firmyears_before_having
    from is_geo2;
    select 
        count(*) as firmyears_after_having
    from is_geo_agg;
    title 'Agg QC3: Firm-Years Lost from HAVING Clause';
quit;



/*==========================================================*/
/* Step 5: Merge Segments with Fundamentals                   */
/*==========================================================*/
/* Inner join: keep only firm-years that appear in both the   */
/* Compustat fundamentals pull (is_raw) and the aggregated    */
/* segment data (is_geo_agg). This is the analysis sample    */
/* of multinationals with financial data AND segment detail.  */
/*==========================================================*/
proc sql;
    create table is_an as
    select 
        a.*,
        b.foreign_assets,
        b.domestic_assets,
        b.foreign_sales,
        b.domestic_sales,
        b.num_segments,
        b.num_foreign_segs,
        b.num_domestic_segs
    from is_raw as a
    inner join is_geo_agg as b
        on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;


/*----------------------------------------------------------*/
/* Step 5 Quality Checks                                     */
/*----------------------------------------------------------*/

/* QC1: Row counts before vs after merge                     */
proc sql;
    select 'Fundamentals' as source, count(*) as n from is_raw
    union all
    select 'Segments Agg', count(*) from is_geo_agg
    union all
    select 'Merged', count(*) from is_an;
    title 'Merge QC1: Row Counts Before vs After';
quit;


/* QC2: Sample composition after merge                       */
proc sql;
    select 
        count(*) as n_firmyears,
        count(distinct gvkey) as n_firms,
        min(fyear) as first_year,
        max(fyear) as last_year
    from is_an;
    title 'Merge QC2: Sample Composition';
quit;


/* QC3: Check for duplicates in merged data                  */
proc sql;
    select count(*) as n_duplicates
    from (
        select gvkey, fyear, count(*) as cnt
        from is_an
        group by gvkey, fyear
        having cnt > 1
    );
    title 'Merge QC3: Duplicate Firm-Years (should be 0)';
quit;


/* QC4: No missing segment fields after merge                */
proc means data=is_an n nmiss;
    var foreign_assets domestic_assets foreign_sales domestic_sales num_segments;
    title 'Merge QC4: Missing Segment Fields (nmiss should be 0)';
run;



/*==========================================================*/
/* Save Merged Dataset to Permanent Library                   */
/*==========================================================*/
/* Label all variables for documentation. This is the base   */
/* analysis sample before regression variable construction.   */
/*==========================================================*/
data isdata.is_mrg;
    set is_an;
    label
        gvkey = 'GVKEY Company Identifier'
        fyear = 'Fiscal Year'
        company_name = 'Company Name'
        sich = 'Historical SIC Code'
        at = 'Total Assets'
        pidom = 'Domestic Pre-tax Income'
        pifo = 'Foreign Pre-tax Income'
        sale = 'Net Sales'
        dltt = 'Long-term Debt'
        dlc = 'Current Debt'
        xrd = 'R&D Expense'
        xad = 'Advertising Expense'
        ppent = 'Net PP&E'
        txt = 'Total Income Tax Expense'
        txfo = 'Foreign Income Tax Expense'
        foreign_assets = 'Foreign Assets (from segments)'
        domestic_assets = 'Domestic Assets (from segments)'
        foreign_sales = 'Foreign Sales (from segments)'
        domestic_sales = 'Domestic Sales (from segments)'
        num_segments = 'Total Number of Segments'
        num_foreign_segs = 'Number of Foreign Segments'
        num_domestic_segs = 'Number of Domestic Segments';
run;

/* Quick summary of all variables in saved dataset           */
proc means data=isdata.is_mrg n nmiss mean median min max;
    var at pidom pifo sale dltt dlc xrd xad ppent txt txfo
        foreign_assets domestic_assets foreign_sales domestic_sales 
        num_segments num_foreign_segs num_domestic_segs;
    title 'Summary Statistics: All Variables in Saved Merged Dataset';
run;



/*==========================================================*/
/* Step 6: Create Regression Variables                        */
/*==========================================================*/
/* Part A: Build the dependent variable â€” income shifting     */
/* measure = foreign profit margin minus domestic profit      */
/* margin. Filter out obs where foreign or domestic sales     */
/* are zero to avoid division errors. Cap at [cap_lower,      */
/* cap_upper] to limit influence of extreme outliers.         */
/*==========================================================*/
data is_reg;
    set isdata.is_mrg;

    /* Require positive sales on both sides for valid margins */
    if foreign_sales > 0 and domestic_sales > 0;

    /* Profit margins by geography */
    foreign_pm  = pifo / foreign_sales;
    domestic_pm = pidom / domestic_sales;

    /* DV: difference in profit margins */
    income_shift = foreign_pm - domestic_pm;

    /* Cap income_shift at macro-defined thresholds */
    if income_shift > &cap_upper then income_shift = &cap_upper;
    else if income_shift < &cap_lower then income_shift = &cap_lower;
run;


/*----------------------------------------------------------*/
/* Part B: Build independent variables for regression        */
/*----------------------------------------------------------*/
/* tax_diff: foreign ETR minus U.S. statutory rate â€” the     */
/*   core tax incentive variable for income shifting.        */
/* ww_profit: worldwide profitability scaled by sales.       */
/* Controls: size, leverage, R&D intensity, advertising      */
/*   intensity, PP&E intensity, year trend, post-TCJA dummy. */
/* Variables capped at [cap_lower, cap_upper] where noted.   */
/* NOTE: tax_diff cap uses ne . guard to prevent SAS from    */
/* converting missing ftr values to the cap boundary.        */
/*----------------------------------------------------------*/
data is_reg;
    set is_reg;

    /* U.S. statutory rate â€” changes at TCJA cutoff */
    if fyear < &tcja_yr then usr = &usr_pre;
    else usr = &usr_post;

    /* Foreign effective tax rate */
    if txfo > 0 and pifo > 0 then ftr = txfo / pifo;
    else ftr = .;

    /* Tax differential: foreign ETR minus U.S. statutory rate */
    tax_diff = ftr - usr;

    /* Cap tax_diff only when non-missing â€” SAS treats missing  */
    /* as negative infinity, so without this guard missing ftr   */
    /* values would be incorrectly capped to cap_lower.          */
    if tax_diff ne . then do;
        if tax_diff > &cap_upper then tax_diff = &cap_upper;
        else if tax_diff < &cap_lower then tax_diff = &cap_lower;
    end;

    /* Worldwide profitability: total pre-tax income / sales */
    ww_profit = (pidom + pifo) / sale;
    if ww_profit > &cap_upper then ww_profit = &cap_upper;
    else if ww_profit < &cap_lower then ww_profit = &cap_lower;

    /* Firm size: natural log of total assets */
    size = log(at);

    /* Leverage: total debt / total assets */
    leverage = (dltt + dlc) / at;

    /* R&D intensity: R&D expense / sales */
    rnd_intensity = xrd / sale;

    /* Advertising intensity: advertising expense / sales */
    ad_intensity = xad / sale;

    /* PP&E intensity: net PP&E / total assets */
    ppe_intensity = ppent / at;

    /* Year trend: years since start of sample */
    year_trend = fyear - &beg_yr;

    /* Post-TCJA indicator */
    if fyear >= &tcja_yr then post_tcja = 1;
    else post_tcja = 0;
run;


/*----------------------------------------------------------*/
/* Step 6 Quality Checks                                     */
/*----------------------------------------------------------*/

/* QC1: How many obs have missing tax_diff (from missing ftr) */
proc sql;
    select 
        count(*) as total_obs,
        sum(missing(ftr)) as missing_ftr,
        sum(missing(tax_diff)) as missing_tax_diff
    from is_reg;
    title 'Reg QC1: Missing Values in Tax Variables';
quit;


/* QC2: Summary stats on all regression variables            */
/* Verify caps held and no unexpected missing values          */
proc means data=is_reg n nmiss mean median min max std;
    var income_shift tax_diff ww_profit size leverage 
        rnd_intensity ad_intensity ppe_intensity 
        year_trend post_tcja usr ftr;
    title 'Reg QC2: Summary Statistics â€” All Regression Variables';
run;


/* QC3: Confirm post_tcja and usr align correctly            */
proc freq data=is_reg;
    tables post_tcja * usr / nocum nopercent;
    title 'Reg QC3: Post-TCJA x USR Cross-Check';
run;


/* QC4: How many obs were capped on each variable?           */
proc sql;
    select 
        sum(income_shift = &cap_upper or income_shift = &cap_lower) as income_shift_capped,
        sum(tax_diff = &cap_upper or tax_diff = &cap_lower) as tax_diff_capped,
        sum(ww_profit = &cap_upper or ww_profit = &cap_lower) as ww_profit_capped
    from is_reg;
    title 'Reg QC4: Number of Capped Observations';
quit;


/* QC5: Sample composition                                   */
proc sql;
    select 
        count(*) as n_firmyears,
        count(distinct gvkey) as n_firms,
        min(fyear) as first_year,
        max(fyear) as last_year
    from is_reg;
    title 'Reg QC5: Sample Composition';
quit;


/* QC6: Distribution of income shifting measure              */
proc univariate data=is_reg;
    var income_shift;
    histogram income_shift / normal;
    title 'Distribution of Income Shifting Measure';
run;



/*==========================================================*/
/* Save Regression Dataset to Permanent Library               */
/*==========================================================*/
data isdata.is_reg;
    set is_reg;
    label
        income_shift   = 'Income Shifting (Foreign PM - Domestic PM)'
        foreign_pm     = 'Foreign Profit Margin'
        domestic_pm    = 'Domestic Profit Margin'
        ftr            = 'Foreign Effective Tax Rate'
        usr            = 'U.S. Statutory Tax Rate'
        tax_diff       = 'Tax Differential (FTR - USR)'
        ww_profit      = 'Worldwide Profitability'
        size           = 'Firm Size (log AT)'
        leverage       = 'Leverage (Total Debt / AT)'
        rnd_intensity  = 'R&D Intensity (XRD / Sale)'
        ad_intensity   = 'Advertising Intensity (XAD / Sale)'
        ppe_intensity  = 'PP&E Intensity (PPENT / AT)'
        year_trend     = 'Year Trend (FYear - beg_yr)'
        post_tcja      = 'Post-TCJA Indicator (1 if FYear >= 2018)';
run;



/*==========================================================*/
/* Step 7: Regressions                                        */
/*==========================================================*/

/*----------------------------------------------------------*/
/* Model 1: Baseline OLS with robust standard errors         */
/*----------------------------------------------------------*/
/* No fixed effects. Tests whether tax_diff, worldwide       */
/* profitability, and firm characteristics explain the        */
/* income shifting measure. /acov produces White's            */
/* heteroskedasticity-consistent standard errors.             */
/*----------------------------------------------------------*/
proc reg data=isdata.is_reg;
    model income_shift =
          tax_diff
          ww_profit
          size
          leverage
          rnd_intensity
          ad_intensity
          ppe_intensity
          year_trend
          post_tcja
    / acov;
    title 'Model 1: OLS â€” Income Shifting (Robust SEs, No Fixed Effects)';
run;
quit;


/*----------------------------------------------------------*/
/* Model 2: OLS with Year Fixed Effects and Robust SEs       */
/*----------------------------------------------------------*/
/* Year dummies absorb time-varying shocks (macro conditions, */
/* policy changes). year_trend and post_tcja are dropped      */
/* since they are collinear with year dummies. Year 2010 is   */
/* the omitted base year. Note: year2017 excluded since 2017  */
/* is not in the sample.                                      */
/*----------------------------------------------------------*/

/* Create year dummies */
data is_reg_fe;
    set isdata.is_reg;
    year2011 = (fyear = 2011);
    year2012 = (fyear = 2012);
    year2013 = (fyear = 2013);
    year2014 = (fyear = 2014);
    year2015 = (fyear = 2015);
    year2016 = (fyear = 2016);
    year2018 = (fyear = 2018);
    year2019 = (fyear = 2019);
    year2020 = (fyear = 2020);
    year2021 = (fyear = 2021);
    year2022 = (fyear = 2022);
    year2023 = (fyear = 2023);
    year2024 = (fyear = 2024);
run;

proc reg data=is_reg_fe;
    model income_shift =
          tax_diff
          ww_profit
          size
          leverage
          rnd_intensity
          ad_intensity
          ppe_intensity
          year2011 year2012 year2013 year2014 year2015 year2016 
          year2018 year2019 year2020 year2021 year2022 year2023 year2024
    / acov;
    title 'Model 2: OLS â€” Income Shifting with Year FE (Robust SEs)';
run;
quit;


/*----------------------------------------------------------*/
/* Model 3: OLS with Interaction Terms and Robust SEs        */
/*----------------------------------------------------------*/
/* Tests whether the TCJA moderated the effect of tax_diff,  */
/* rnd_intensity, and ww_profit on income shifting. A         */
/* significant interaction means the relationship changed     */
/* after the 2017 tax reform, not just the level.            */
/*----------------------------------------------------------*/
data is_reg_int;
    set isdata.is_reg;
    tax_diff_x_post      = tax_diff * post_tcja;
    rnd_intensity_x_post = rnd_intensity * post_tcja;
    ww_profit_x_post     = ww_profit * post_tcja;
run;

proc reg data=is_reg_int;
    model income_shift =
          tax_diff
          ww_profit
          size
          leverage
          rnd_intensity
          ad_intensity
          ppe_intensity
          year_trend
          post_tcja
          tax_diff_x_post
          rnd_intensity_x_post
          ww_profit_x_post
    / acov;
    title 'Model 3: OLS â€” Income Shifting with Interactions (Robust SEs)';
run;
quit;


/*----------------------------------------------------------*/
/* Model 4: OLS with Industry Fixed Effects (Robust SEs)     */
/*----------------------------------------------------------*/
/* Adds 2-digit SIC industry dummies to the baseline model   */
/* to control for unobserved industry-level differences in   */
/* income shifting behavior. Industries with <10 obs are     */
/* collapsed into sic2_grp=99 ("Other"). PROC SURVEYREG      */
/* provides heteroskedasticity-robust (sandwich) SEs.        */
/*----------------------------------------------------------*/

/* Create 2-digit SIC and collapse small industries */
data is_reg_ind;
    set isdata.is_reg;
    sic2 = floor(sich / 100);
run;

proc sql;
    create table sic2_counts as
    select sic2, count(*) as n
    from is_reg_ind
    where sic2 is not missing
    group by sic2;
quit;

proc sql;
    create table is_reg_ind2 as
    select a.*,
        case when b.n < 10 or a.sic2 is missing then 99 
             else a.sic2 end as sic2_grp
    from is_reg_ind as a
    left join sic2_counts as b
        on a.sic2 = b.sic2;
quit;

/* QC: Check industry distribution after collapsing */
proc freq data=is_reg_ind2 order=freq;
    tables sic2_grp / nocum;
    title 'QC: 2-Digit SIC After Collapsing Small Industries';
run;

proc surveyreg data=is_reg_ind2;
    class sic2_grp;
    model income_shift =
          tax_diff
          ww_profit
          size
          leverage
          rnd_intensity
          ad_intensity
          ppe_intensity
          year_trend
          post_tcja
          sic2_grp
    / solution;
    title 'Model 4: OLS â€” Industry FE with Robust SEs (SURVEYREG)';
run;
quit;



/*==========================================================*/
/* Step 8: Additional Analysis                                */
/*==========================================================*/

/*----------------------------------------------------------*/
/* 8A: Pre vs Post TCJA Tax Differentials                    */
/*----------------------------------------------------------*/
/* Compare actual mean tax rates before and after TCJA to    */
/* confirm the reform shifted the tax landscape as expected. */
/*----------------------------------------------------------*/
proc means data=isdata.is_reg mean median;
    class post_tcja;
    var tax_diff ftr usr;
    title 'Actual Tax Differentials: Pre vs Post TCJA';
run;


/*----------------------------------------------------------*/
/* 8B: VIF Test for Multicollinearity                        */
/*----------------------------------------------------------*/
/* VIF > 10 suggests problematic collinearity. Run on the    */
/* baseline model specification (Model 1 variables).         */
/*----------------------------------------------------------*/
proc reg data=isdata.is_reg;
    model income_shift = 
        tax_diff ww_profit size leverage 
        rnd_intensity ad_intensity ppe_intensity 
        year_trend post_tcja / vif;
    title 'VIF Test for Multicollinearity';
run;
quit;



/*==========================================================*/
/* Step 9: Correlation Matrix                                 */
/*==========================================================*/
/* Pearson correlations among all regression variables.       */
/* Look for: (1) high correlations among IVs that might      */
/* signal collinearity beyond what VIF caught, and           */
/* (2) correlation between DV and key IVs as a sanity check. */
/*==========================================================*/
proc corr data=isdata.is_reg;
    var income_shift tax_diff ww_profit size leverage 
        rnd_intensity ad_intensity ppe_intensity 
        year_trend post_tcja;
    title 'Pearson Correlation Matrix â€” Regression Variables';
run;



/*==========================================================*/
/* Sensitivity Analysis: Exclude Ambiguous Domestic Segments  */
/*==========================================================*/
/* Re-run the full pipeline after dropping "North America",   */
/* "Americas", "The Americas", and "Corporate" entirely â€”     */
/* these segments don't get classified as domestic OR foreign. */
/* All datasets prefixed with sens_ to avoid overwriting.     */
/*==========================================================*/

/*----------------------------------------------------------*/
/* Sens Step 1: Remove ambiguous segments before classifying  */
/*----------------------------------------------------------*/
data sens_geo;
    set is_geo;
    snms_upper = upcase(snms);

    /* Drop ambiguous segments entirely */
    if snms_upper in (
        'NORTH AMERICA', 'AMERICAS', 'THE AMERICAS', 'CORPORATE'
    ) then delete;

    /* Classify remaining segments */
    domestic = 0;

    if snms_upper in (
        'UNITED STATES OF AMERICA',
        'UNITED STATES',
        'U.S.',
        'US',
        'USA',
        'U S',
        'U.S.A.',
        'AMERICA',
        'DOMESTIC'
    ) then domestic = 1;
    else if snms_upper in (
        'ALABAMA','ALASKA','ARIZONA','ARKANSAS','CALIFORNIA',
        'COLORADO','CONNECTICUT','DELAWARE','FLORIDA','GEORGIA',
        'HAWAII','IDAHO','ILLINOIS','INDIANA','IOWA','KANSAS',
        'KENTUCKY','LOUISIANA','MAINE','MARYLAND','MASSACHUSETTS',
        'MICHIGAN','MINNESOTA','MISSISSIPPI','MISSOURI','MONTANA',
        'NEBRASKA','NEVADA','NEW HAMPSHIRE','NEW JERSEY','NEW MEXICO',
        'NEW YORK','NORTH CAROLINA','NORTH DAKOTA','OHIO','OKLAHOMA',
        'OREGON','PENNSYLVANIA','RHODE ISLAND','SOUTH CAROLINA',
        'SOUTH DAKOTA','TENNESSEE','TEXAS','UTAH','VERMONT',
        'VIRGINIA','WASHINGTON','WEST VIRGINIA','WISCONSIN','WYOMING'
    ) then domestic = 1;

    foreign = 1 - domestic;
run;


/*----------------------------------------------------------*/
/* Sens Step 2: Aggregate to firm-year level                  */
/*----------------------------------------------------------*/
proc sql;
    create table sens_geo_agg as
    select 
        gvkey,
        fyear,
        sum(ias * foreign) as foreign_assets, 
        sum(ias * domestic) as domestic_assets,
        sum(sales * foreign) as foreign_sales,
        sum(sales * domestic) as domestic_sales,
        count(*) as num_segments,
        sum(foreign) as num_foreign_segs,
        sum(domestic) as num_domestic_segs
    from sens_geo
    group by gvkey, fyear
    having foreign_assets > 0 and domestic_assets > 0;
quit;


/*----------------------------------------------------------*/
/* Sens Step 3: Merge with fundamentals                      */
/*----------------------------------------------------------*/
proc sql;
    create table sens_an as
    select 
        a.*,
        b.foreign_assets,
        b.domestic_assets,
        b.foreign_sales,
        b.domestic_sales,
        b.num_segments
    from is_raw as a
    inner join sens_geo_agg as b
        on a.gvkey = b.gvkey and a.fyear = b.fyear;
quit;


/*----------------------------------------------------------*/
/* Sens Step 4: Build regression variables                   */
/*----------------------------------------------------------*/
data sens_reg;
    set sens_an;

    /* Require positive sales on both sides */
    if foreign_sales > 0 and domestic_sales > 0;

    /* DV */
    foreign_pm  = pifo / foreign_sales;
    domestic_pm = pidom / domestic_sales;
    income_shift = foreign_pm - domestic_pm;
    if income_shift > &cap_upper then income_shift = &cap_upper;
    else if income_shift < &cap_lower then income_shift = &cap_lower;

    /* IVs */
    if fyear < &tcja_yr then usr = &usr_pre;
    else usr = &usr_post;

    if txfo > 0 and pifo > 0 then ftr = txfo / pifo;
    else ftr = .;

    tax_diff = ftr - usr;
    if tax_diff ne . then do;
        if tax_diff > &cap_upper then tax_diff = &cap_upper;
        else if tax_diff < &cap_lower then tax_diff = &cap_lower;
    end;

    ww_profit = (pidom + pifo) / sale;
    if ww_profit > &cap_upper then ww_profit = &cap_upper;
    else if ww_profit < &cap_lower then ww_profit = &cap_lower;

    size = log(at);
    leverage = (dltt + dlc) / at;
    rnd_intensity = xrd / sale;
    ad_intensity = xad / sale;
    ppe_intensity = ppent / at;
    year_trend = fyear - &beg_yr;
    if fyear >= &tcja_yr then post_tcja = 1;
    else post_tcja = 0;
run;


/*----------------------------------------------------------*/
/* Sens QC: Compare sample sizes â€” main vs sensitivity       */
/*----------------------------------------------------------*/
proc sql;
    select 'Main Analysis' as source, 
           count(*) as n_obs, 
           count(distinct gvkey) as n_firms 
    from isdata.is_reg
    union all
    select 'Sensitivity (Excl Ambiguous)', 
           count(*), 
           count(distinct gvkey) 
    from sens_reg;
    title 'Sensitivity QC: Sample Size Comparison';
quit;


/*----------------------------------------------------------*/
/* Sens Step 5: Run baseline regression (Model 1 equivalent) */
/*----------------------------------------------------------*/
proc reg data=sens_reg;
    model income_shift =
          tax_diff
          ww_profit
          size
          leverage
          rnd_intensity
          ad_intensity
          ppe_intensity
          year_trend
          post_tcja
    / acov;
    title 'Sensitivity: Model 1 â€” Excluding Ambiguous Segments (Robust SEs)';
run;
quit;


/*----------------------------------------------------------*/
/* Save sensitivity regression dataset                       */
/*----------------------------------------------------------*/
data isdata.sens_reg;
    set sens_reg;
    label
        income_shift   = 'Income Shifting (Foreign PM - Domestic PM)'
        tax_diff       = 'Tax Differential (FTR - USR)'
        ww_profit      = 'Worldwide Profitability'
        size           = 'Firm Size (log AT)'
        leverage       = 'Leverage (Total Debt / AT)'
        rnd_intensity  = 'R&D Intensity (XRD / Sale)'
        ad_intensity   = 'Advertising Intensity (XAD / Sale)'
        ppe_intensity  = 'PP&E Intensity (PPENT / AT)'
        year_trend     = 'Year Trend (FYear - beg_yr)'
        post_tcja      = 'Post-TCJA Indicator (1 if FYear >= 2018)';
run;



/*----------------------------------------------------------------------------*/
/* Export regression dataset to CSV for R visualizations and regressions      */
/*----------------------------------------------------------------------------*/
proc export data=isdata.is_reg
    outfile="~/inc_shift/is_reg.csv"
    dbms=csv replace;
run;

/*----------------------------------------------------------------------------*/
/* Export regression dataset to CSV for R visualizations and regressions      */
/*----------------------------------------------------------------------------*/
proc export data=isdata.sens_reg
    outfile="~/inc_shift/sens_reg.csv"
    dbms=csv replace;
run;
