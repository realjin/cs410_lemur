
/// A Sample Retrieval Evaluation Program
#include "common_headers.hpp"
#include "BasicDocStream.hpp"
#include "IndexManager.hpp"
#include "Param.hpp"
#include "String.hpp"
#include "IndexedReal.hpp"
#include "ScoreAccumulator.hpp"
#include "ResultFile.hpp"



using namespace lemur::api; 
// these are the parameters

namespace LocParam{
  static std::string docIndex; // document index
  static std::string queryStream; // query stream
  static std::string resultFile; // result file name

  double weightParam; // weighting parameter
  int resultCutoff; // the number of top-ranked documents to return for each query
  void get() {
    // the string with quotes are the actual variable names to use for specifying the parameters
    docIndex    = ParamGetString("index"); 
    queryStream = ParamGetString("query");
    resultFile = ParamGetString("result","res");
    weightParam = ParamGetDouble("param", 0.5);
    resultCutoff = ParamGetInt("resultCutoff", 200);
  }    
};

void GetAppParam() 
{
  LocParam::get();
}


//=========== The following two functions are empty ====================
//=========== You must implement them ==================================

// compute the weight of a matched term
double computeWeight(int docID,
		     int termID, 
		     int docTermFreq, 
		     int qryTermFreq,
		     Index & ind)
{
  // You need to implement this function 
}

// compute the adjusted score
double computeAdjustedScore(double origScore, // the score from the accumulator
			    int docID, // doc ID
			    int qryFreqSum, // total freq sum of the query
			    Index &ind) // index
{
  // You need to implement this function
}


//================= This function has one line missing  =======================
//================= You need to add this one-line code  ======================


// retrieval execution
void retrieval(Index &ind, // index 
	       DocStream &qryStream, // query stream 
	       ScoreAccumulator &scAcc, // score accumulator 
	       ResultFile &resFile) // result file
{
  
  int *query = new int[ind.termCountUnique()+1]; // allocate an array to hold all query terms
  
  IndexedRealVector scores(ind.docCount()); // to store and sort scores

  int t;

  int qryFreqSum; // to compute query length

  //TextQuery *q;
  // go through each query
  qryStream.startDocIteration();

  while (qryStream.hasMore()) {
    Document *qryDoc = qryStream.nextDoc();       
    string queryID = qryDoc->getID();
    cerr << "query: "<< queryID <<endl;

    // for each query, first reset the accumulator
    scAcc.reset();

    // then  compute query term frequency and store them in an array
    // this is an inefficient way, but would make the project easier
    for (t=1; t<=ind.termCountUnique(); t++) {
      query[t]=0;
    }

    qryFreqSum =0;
    qryDoc->startTermIteration();
    while (qryDoc->hasMore()) {
      const Term *qryTerm = qryDoc->nextTerm();
      int qryTermID = ind.term(qryTerm->spelling());
      query[qryTermID] ++;
      qryFreqSum ++;
    }

    // finally,  go through each query term to accumulate scores
    for (t=1; t<=ind.termCountUnique();t++) {
      if (query[t]>0) {
	// fetch inverted entries
	DocInfoList *dList = ind.docInfoList(t);

	// iterate over all entries
	dList->startIteration();
	while (dList->hasMore()) {
	  DocInfo *info = dList->nextEntry();
	  // for each entry, compute the weight contribution
	  double wt = computeWeight(info->docID(),  // doc ID
				    t, // term ID
				    info->termCount(), // freq of term t in this doc
				    query[t], // freq of term t in the query
				    ind);
	}
	delete dList;
      }
    }

    // now copy scores into the result data structure, adjust them if necessary.
    scores.clear();
    double s;
    int d;
    for (d=1; d<=ind.docCount(); d++) {
      if (scAcc.findScore(d,s)) {
      } else {
	s=0;
      }
      scores.PushValue(d, computeAdjustedScore(s, // the score from the accumulator
					       d, // doc ID
					       qryFreqSum, // total freq sum of the query
					       ind)); // index
    }
    scores.Sort();

    // write the results into the result file
    resFile.writeResults(queryID, &scores, LocParam::resultCutoff);
  }
} 

//================= The rest of the code is complete =======================

int AppMain(int argc, char * argv[]) {

  Index *ind;

  // Step 1. open the index
  try {
    ind = IndexManager::openIndex(LocParam::docIndex);
  } 
  catch (Exception &ex) {
    ex.writeMessage();
    throw Exception("RetrievalEval", "can't open index, check parameter index");
  }

  // Step 2. open the query stream

  DocStream *qryStream;
  try {
    qryStream = new lemur::parse::BasicDocStream(LocParam::queryStream);
  } 
  catch (Exception &ex) {
    ex.writeMessage(cerr);
    throw Exception("RetrievalEval", "Can't open query file, check parameter query");
  }

  // Step 3. create result file

  ofstream result(LocParam::resultFile.c_str());
  ResultFile resFile(false);
  resFile.openForWrite(result, *ind);

  // Step 4. construct a score accumulator  
  lemur::retrieval::ArrayAccumulator accumulator(ind->docCount());

  // Finally, call the retrieval procedure
  retrieval(*ind, *qryStream, accumulator, resFile); 

  result.close();
  delete qryStream;

  return 0;
}

