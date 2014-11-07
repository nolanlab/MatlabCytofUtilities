
package com.mathworks.training.xml;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import javax.xml.namespace.NamespaceContext;

/**
 * 
 * Simple implementation of the NamespaceContext interface for using 
 * XPath with namespaces
 *
 * Note - Much of this code is based off an example from
 * http://www.ibm.com/developerworks/xml/library/x-nmspccontext/index.html
 * 
 */
public class XMLNodeNamespaceContext implements NamespaceContext {

	private Map<String,String> prefixToURI;
	private Map<String,String> URIToPrefix;
	/**
	 * 
	 */
	public XMLNodeNamespaceContext() {
		prefixToURI = new HashMap<String, String>();
		URIToPrefix = new HashMap<String, String>();
	}
	
	public void addPrefixMapping(String prefix, String uri)	{
		prefixToURI.put(prefix,uri);
		URIToPrefix.put(uri,prefix);
	}
	
	
	public Map<String,String> getPrefixURIMap() {
		return prefixToURI;
	}

	/* (non-Javadoc)
	 * @see javax.xml.namespace.NamespaceContext#getNamespaceURI(java.lang.String)
	 */
	@Override
	public String getNamespaceURI(String prefix) {
		return prefixToURI.get(prefix);
	}

	/* (non-Javadoc)
	 * @see javax.xml.namespace.NamespaceContext#getPrefix(java.lang.String)
	 */
	@Override
	public String getPrefix(String uri) {
		return URIToPrefix.get(uri);
	}

	/* (non-Javadoc)
	 * @see javax.xml.namespace.NamespaceContext#getPrefixes(java.lang.String)
	 */
	@Override
	public Iterator getPrefixes(String arg0) {
		// TODO Not currently implemented
		return null;
	}

}
