provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "rg" {
  name     = "rg_KCR_NTL_PCH"
  location = "East US" 
}

resource "azurerm_virtual_network" "vnet" {
  name                = "vnetKCRNTLPCH"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "subnetKCRNTLPCH"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_interface" "nic1" {
  name                = "nic1KCRNTLPCH"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_network_interface" "nic2" {
  name                = "nic2KCRNTLPCH"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_availability_set" "av" {
  name                = "availabilitySet"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  managed             = true
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "vm1KCRNTLPCH"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  availability_set_id = azurerm_availability_set.av.id
  size                = "Standard_DS1_v2"
  admin_username      = "adminuser"

  disable_password_authentication= false
  network_interface_ids = [azurerm_network_interface.nic1.id]
  admin_password      = "exempleOfPassWord10942!" 

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer                 = "0001-com-ubuntu-server-focal"
    publisher             = "Canonical"
    sku                   = "20_04-lts-gen2"
    version               = "latest"
  }

  custom_data = base64encode(file("scripts/init_apache2.sh"))
}



resource "azurerm_linux_virtual_machine" "vm2" {
  name                = "vm2KCRNTLPCH"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  availability_set_id = azurerm_availability_set.av.id
  size                = "Standard_DS1_v2"

  disable_password_authentication= false
  admin_username      = "adminuser"
  network_interface_ids = [azurerm_network_interface.nic2.id]
  admin_password      = "exempleOfPassWord10942!"

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    offer                 = "0001-com-ubuntu-server-focal"
    publisher             = "Canonical"
    sku                   = "20_04-lts-gen2"
    version               = "latest"
  }

  custom_data = base64encode(file("scripts/init_apache2.sh"))
}

resource "azurerm_public_ip" "lb_pip" {
  name                = "pipKCRNTLPCH"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "lb" {
  name                = "lbKCRNTLPCH"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.lb_pip.id
  }
}

resource "azurerm_lb_backend_address_pool" "bap" {
  loadbalancer_id = azurerm_lb.lb.id
  name            = "bapKCRNTLPCH"
}

resource "azurerm_lb_probe" "probe" {
  name                = "probeKCRNTLPCH"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Http"
  request_path        = "/"
  port                = 80
}

resource "azurerm_lb_rule" "rule" {
  name                = "ruleKCRNTLPCH"
  loadbalancer_id     = azurerm_lb.lb.id
  protocol            = "Tcp"
  frontend_port       = 80
  backend_port        = 80
  frontend_ip_configuration_name = "PublicIPAddress"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.bap.id]
  probe_id                        = azurerm_lb_probe.probe.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nic1-bap" {
  network_interface_id    = azurerm_network_interface.nic1.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bap.id
}

resource "azurerm_network_interface_backend_address_pool_association" "nic2-bap" {
  network_interface_id    = azurerm_network_interface.nic2.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.bap.id
}
